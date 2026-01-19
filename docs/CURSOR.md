[**<---**](README.md)

## Cursor Remote-SSH

```bash
task server:setup-remote-cursor
```

Then in Cursor:
1. Install "Remote - SSH" extension
2. Cmd+Shift+P → "Remote-SSH: Connect to Host..."
3. Select server name (from Terraform `server_name` variable, default = "giftfinder-test")
4. A new Cursor window will open on the server, open a directory, eg. `/home/ubuntu` or `/var/log`

**Note:** Only use this for troubleshooting, do not make actual changes on the server, these need to be made using ansible.
