from __future__ import annotations

DOCUMENTATION = r"""
name: unixy_noskip
type: stdout
short_description: unixy, but skipped tasks print nothing
description:
  - Same output as community.general.unixy, except a task name is printed only
    once the task produces a non-skipped result.
extends_documentation_fragment:
  - default_callback
requirements:
  - set as stdout in configuration
"""

from ansible_collections.community.general.plugins.callback.unixy import CallbackModule as UnixyCallback


class CallbackModule(UnixyCallback):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "stdout"
    CALLBACK_NAME = "unixy_noskip"

    _pending_task_line = None

    def _flush_task_line(self):
        if self._pending_task_line is not None:
            self._display.display(self._pending_task_line)
            self._pending_task_line = None

    def v2_playbook_on_task_start(self, task, is_conditional):
        self._get_task_display_name(task)
        self._pending_task_line = None
        if self.task_display_name is not None:
            if task.check_mode and self.get_option("check_mode_markers"):
                self._pending_task_line = f"{self.task_display_name} (check mode)..."
            else:
                self._pending_task_line = f"{self.task_display_name}..."

    def v2_runner_on_ok(self, result, msg="ok", display_color=None):
        self._flush_task_line()
        if display_color is None:
            super().v2_runner_on_ok(result, msg)
        else:
            super().v2_runner_on_ok(result, msg, display_color)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._flush_task_line()
        super().v2_runner_on_failed(result, ignore_errors)

    def v2_runner_on_unreachable(self, result):
        self._flush_task_line()
        super().v2_runner_on_unreachable(result)

    def v2_runner_item_on_ok(self, result):
        self._flush_task_line()
        super().v2_runner_item_on_ok(result)

    def v2_runner_item_on_failed(self, result):
        self._flush_task_line()
        super().v2_runner_item_on_failed(result)
