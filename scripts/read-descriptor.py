#!/usr/bin/env python3
"""
Read and parse deployment descriptor YAML file.

Usage: read-descriptor.py <DESCRIPTOR_PATH>

Outputs: registry_name|image_name|service_name (pipe-separated)
Exits with non-zero code on error.
"""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("❌ Error: PyYAML is required. Install with: pip install PyYAML", file=sys.stderr)
    sys.exit(1)


def main():
    """Main entry point."""
    if len(sys.argv) != 2:
        print("❌ Error: Invalid number of arguments", file=sys.stderr)
        print(f"Usage: {sys.argv[0]} <DESCRIPTOR_PATH>", file=sys.stderr)
        sys.exit(1)
    
    descriptor_path = Path(sys.argv[1])
    
    # Validate descriptor exists
    if not descriptor_path.exists():
        print(f"❌ Error: Descriptor file does not exist: {descriptor_path}", file=sys.stderr)
        sys.exit(1)
    
    if descriptor_path.suffix not in ('.yml', '.yaml'):
        print(f"❌ Error: Descriptor must have .yml or .yaml extension: {descriptor_path}", file=sys.stderr)
        sys.exit(1)
    
    # Read and parse descriptor
    try:
        with open(descriptor_path, 'r') as f:
            descriptor = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"❌ Error: Invalid YAML in descriptor: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: Failed to read descriptor: {e}", file=sys.stderr)
        sys.exit(1)
    
    if not isinstance(descriptor, dict):
        print("❌ Error: Descriptor must be a YAML object", file=sys.stderr)
        sys.exit(1)
    
    # Validate required fields
    required_fields = ['registry_name', 'image_name', 'service_name']
    missing = [field for field in required_fields if field not in descriptor]
    if missing:
        print(f"❌ Error: Missing required fields in descriptor: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    
    # Output pipe-separated values
    print(f"{descriptor['registry_name']}|{descriptor['image_name']}|{descriptor['service_name']}")


if __name__ == '__main__':
    main()
