#!/usr/bin/env python3
"""
Validate embedded bash scripts in Taskfiles with shellcheck.
"""

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple

try:
    import yaml
except ImportError:
    print("❌ PyYAML not found. Install with: pip install PyYAML", file=sys.stderr)
    sys.exit(1)


def extract_taskfile_scripts(taskfile_path: Path) -> List[Tuple[str, int, str, int]]:
    """Extract embedded scripts from a Taskfile. Returns (task_name, cmd_index, script_content, total_cmds)."""
    try:
        with open(taskfile_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"⚠️  Warning: Failed to parse {taskfile_path}: {e}", file=sys.stderr)
        return []
    
    if not isinstance(data, dict):
        return []
    
    # Extract tasks (handle both 'tasks:' key and top-level)
    tasks = data.get('tasks', {}) if isinstance(data.get('tasks'), dict) else {
        k: v for k, v in data.items()
        if k not in ('version', 'includes', 'vars') and isinstance(v, dict)
    }
    
    scripts = []
    for task_name, task_data in tasks.items():
        if not isinstance(task_data, dict):
            continue
        
        cmds = task_data.get('cmds', [])
        if isinstance(cmds, str):
            cmds = [cmds]
        elif not isinstance(cmds, list):
            continue
        
        for idx, cmd in enumerate(cmds):
            if not isinstance(cmd, str):
                continue
            
            script = cmd.strip()
            if not script or script in ('null', '~'):
                continue
            
            # Only check scripts with bash constructs or multi-line
            if len(script.splitlines()) > 1 or re.search(r'\$|if \[|for |while ', script):
                scripts.append((task_name, idx, script, len(cmds)))
    
    return scripts


def replace_task_variables(script: str) -> str:
    """Replace Task variables {{.VAR}} with $VAR for shellcheck compatibility."""
    return re.sub(r'\{\{\.([A-Z_][A-Z0-9_]*)\}\}', r'$\1', script)


def run_shellcheck(script_content: str) -> Tuple[int, str]:
    """Run shellcheck on a script. Returns (exit_code, output)."""
    try:
        result = subprocess.run(
            ['shellcheck', '-s', 'bash', '-'],
            input=script_content,
            capture_output=True,
            text=True,
            check=False
        )
        return result.returncode, (result.stderr or result.stdout or "")
    except FileNotFoundError:
        print("❌ shellcheck not found. Install with: brew install shellcheck", file=sys.stderr)
        sys.exit(1)


def count_issues_in_output(output: str) -> int:
    """Count number of SC#### codes in shellcheck output (each represents one issue)."""
    if not output:
        return 0
    return len(set(re.findall(r'SC\d+', output)))


def parse_shellcheck_output(output: str) -> Tuple[List[str], int]:
    """Parse shellcheck output to extract error messages with line numbers. Returns (errors, issue_count)."""
    errors = []
    issue_count = 0
    current_line_num = None
    icons = {'error': '❌', 'warning': '⚠️ ', 'info': 'ℹ️ ', 'style': '•'}
    
    for line in output.splitlines():
        line = line.strip()
        if not line or line.startswith('For more information:'):
            continue
        
        # Extract line number: "In - line X:"
        match = re.match(r'In\s+-\s+line\s+(\d+):', line)
        if match:
            current_line_num = int(match.group(1))
            continue
        
        # Extract error: "^-- SC#### (level): message"
        match = re.search(r'SC(\d+)\s*\((\w+)\):\s*(.+)', line)
        if match:
            sc_code, level, message = match.groups()
            issue_count += 1
            icon = icons.get(level, '•')
            line_prefix = f"Line {current_line_num}: " if current_line_num else ""
            errors.append(f"  {icon} {line_prefix}SC{sc_code} ({level}): {message}")
        
        # Extract suggestion
        if 'Did you mean:' in line:
            suggestion = line.replace('Did you mean:', '').strip()
            if suggestion:
                errors.append(f"    💡 Suggestion: {suggestion}")
    
    return errors, issue_count


def validate_embedded_scripts(taskfile_path: Path) -> Tuple[int, int, int]:
    """Validate embedded scripts from a Taskfile. Returns (script_count, error_count, issue_count)."""
    error_count = 0
    total_issues = 0
    extracted_scripts = extract_taskfile_scripts(taskfile_path)
    
    for task_name, cmd_idx, script_content, total_cmds in extracted_scripts:
        exit_code, output = run_shellcheck(replace_task_variables(script_content))
        
        if exit_code != 0:
            task_label = f"task '{task_name}'" + (f" (cmd #{cmd_idx})" if total_cmds > 1 else "")
            print(f"\n📄 {taskfile_path.name} → {task_label}", flush=True)
            
            if output and output.strip():
                errors, issue_count = parse_shellcheck_output(output)
                if errors:
                    for error in errors:
                        print(error, flush=True)
                    total_issues += issue_count
                else:
                    # Fallback: print raw output and count issues
                    for line in output.splitlines():
                        if line.strip() and not line.startswith('For more information:'):
                            print(f"  {line}", flush=True)
                    total_issues += count_issues_in_output(output) or 1
            else:
                print("  ⚠️  shellcheck found issues (no detailed output)", flush=True)
                total_issues += 1
            
            error_count += 1
    
    return len(extracted_scripts), error_count, total_issues


def main():
    """Main entry point."""
    iac_root = Path(__file__).parent.parent.absolute()
    os.chdir(iac_root)
    
    print("\n🔍 Validating embedded scripts in Taskfiles...")
    
    total_errors = 0
    total_issues = 0
    script_count = 0
    
    taskfiles = list(iac_root.glob("Taskfile*.yml")) + list((iac_root / "tasks").glob("Taskfile*.yml"))
    
    for taskfile in sorted(taskfiles):
        if taskfile.is_file():
            scripts, errors, issues = validate_embedded_scripts(taskfile)
            script_count += scripts
            total_errors += errors
            total_issues += issues
    
    print("")
    if total_errors == 0:
        print(f"✅ Taskfile script validation passed ({script_count} embedded scripts)")
        sys.exit(0)
    else:
        print(f"❌ Taskfile script validation found {total_issues} issue(s) in {total_errors} script(s)")
        sys.exit(1)


if __name__ == "__main__":
    main()
