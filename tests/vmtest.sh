#!/bin/bash
# minibak VM test (Debian/Ubuntu with systemd) - run from the project root:  bash tests/vmtest.sh 2>&1 | tee vmtest.log
cd "$(dirname "$(readlink -f "$0")")"
[ -f install.sh ] || cd ..    # works from the project root and from tests/
[ -f install.sh ] && [ -f minibak.sh ] && [ -f conf ] || { echo "install.sh / minibak.sh / conf not found next to this script"; exit 1; }

P=0; F=0; FAILS=()
D=/var/backups/minibak
step() { echo; echo "================ $* ================"; }
chk()  { if eval "$2" >/dev/null 2>&1; then echo "  PASS  $1"; P=$((P+1)); else echo "  FAIL  $1"; F=$((F+1)); FAILS+=("$1"); fi; }

step "0. prepare (clean slate, test settings in ./conf)"
sudo -v || exit 1
chmod +x install.sh
[ -f conf.orig ] || cp conf conf.orig
sed -i 's|^[[:space:]]*dir_src=.*|    dir_src="/srv/testdata"|; s|^[[:space:]]*bool_timerEnabled=.*|    bool_timerEnabled=true|' conf
printf 'y\nn\ny\ny\ny\n' | ./install.sh uninstall >/dev/null 2>&1
sudo rm -rf $D /srv/testdata /var/log/minibak.log /tmp/minibak
sudo rm -f install.log uninstall.log minibak-final.log
sudo mkdir -p /srv/testdata/subdir
for i in 1 2 3; do echo "file $i" | sudo tee /srv/testdata/file$i.txt >/dev/null; done
echo nested | sudo tee /srv/testdata/subdir/nested.txt >/dev/null
grep -n -E 'dir_src=|bool_timerEnabled=|int_keepFullWeeks=' conf

step "1. install (as normal user, tests the sudo re-exec)"
printf 'y\n' | ./install.sh
chk "minibak is executable" 'test -x /usr/bin/minibak'
chk "config + template copied" 'test -f /etc/minibak.conf && test -f /etc/minibak.conf.template'
chk "config permissions are 644 (not executable)" '[ "$(stat -c %a /etc/minibak.conf)" = 644 ]'
chk "service ExecStart has no quotes" 'grep -q "^ExecStart=/usr/bin/minibak -c /etc/minibak.conf$" /etc/systemd/system/minibak.service'
chk "timer unit file exists" 'test -f /etc/systemd/system/minibak.timer'
chk "timer is enabled" 'systemctl is-enabled --quiet minibak.timer'
chk "timer is running" 'systemctl is-active --quiet minibak.timer'
chk "install.log has no ERROR" '! grep -q "\[ERROR\]" install.log'
chk "install.log has both copy-job lines (service + timer)" '[ "$(grep -c "Copy job finished" install.log)" = 2 ]'
chk "timer is scheduled for 00:00 / 12:00" 'systemctl list-timers minibak.timer --no-pager | grep -q -E " (00|12):00:00 "'
systemctl list-timers minibak.timer --no-pager

step "2. manual backups + hardlink check"
minibak -c default >/dev/null 2>&1
sleep 2
echo more | sudo tee -a /srv/testdata/file1.txt >/dev/null
minibak -c default >/dev/null 2>&1
A=$(sudo ls -d $D/backup_* | sort | head -1)
B=$(sudo ls -d $D/backup_* | sort | tail -1)
sudo ls $D
chk "two backups exist" '[ "$(sudo ls -d $D/backup_* | wc -l)" = 2 ]'
chk "unchanged file2 is the same inode (hardlink)" '[ "$(sudo stat -c %i $A/testdata/file2.txt)" = "$(sudo stat -c %i $B/testdata/file2.txt)" ]'
chk "changed file1 got its own copy" '[ "$(sudo stat -c %i $A/testdata/file1.txt)" != "$(sudo stat -c %i $B/testdata/file1.txt)" ]'
chk "old backup still holds the old file1" '[ "$(sudo cat $A/testdata/file1.txt)" = "file 1" ]'
chk "nested file was backed up" 'sudo test -f $B/testdata/subdir/nested.txt'
chk "main log has a success entry" 'sudo grep -q "Backup job completed successfully" /var/log/minibak.log'

step "3. run it the way the timer does (systemd service)"
sleep 2
sudo systemctl start minibak.service
sudo journalctl -u minibak.service -n 10 --no-pager
chk "service did not fail" '! systemctl is-failed --quiet minibak.service'
chk "three backups now" '[ "$(sudo ls -d $D/backup_* | wc -l)" = 3 ]'

step "4. retention (fake backups from 80 days ago up to yesterday)"
for d in $(seq 80 -1 1); do for h in 00-00-05 12-00-04; do sudo mkdir -p $D/backup_$(date -d "-$d days" +%F)_$h; done; done
sleep 2
minibak -c default >/dev/null 2>&1
thisMonday=$(date -d "-$(( $(date +%u) - 1 )) days" +%F)
cutoff=$(date -d "$thisMonday -4 weeks" +%F)
echo "cutoff = Monday of the oldest week that is kept in full: $cutoff"
oldnames() { local n d; sudo ls $D | grep '^backup_' | while read -r n; do d=${n#backup_}; d=${d%%_*}; [[ $d < $cutoff ]] && echo "$n"; done; }
oldweeks() { local n d; oldnames | while read -r n; do d=${n#backup_}; date -d "${d%%_*}" +%G-%V; done; }
expectedWeeks=$(for d in $(seq 80 -1 1); do x=$(date -d "-$d days" +%F); [[ $x < $cutoff ]] && date -d "$x" +%G-%V; done | sort -u | wc -l)
missing=0
for d in $(seq 1 80); do x=$(date -d "-$d days" +%F); if [[ ! $x < $cutoff ]]; then for h in 00-00-05 12-00-04; do sudo test -d $D/backup_${x}_$h || missing=$((missing+1)); done; fi; done
sudo ls $D
chk "no old week has more than one backup" '[ -z "$(oldweeks | sort | uniq -d)" ]'
chk "every old week still has its one backup ($expectedWeeks weeks)" '[ "$(oldweeks | sort -u | wc -l)" = "$expectedWeeks" ]'
chk "the kept old backups are the first of their week (00-00-05)" '[ -z "$(oldnames | grep -v _00-00-05)" ]'
chk "all backups from the fully kept weeks are still there" '[ $missing -eq 0 ]'
chk "today's four real backups survived" '[ "$(sudo ls -d $D/backup_$(date +%F)_* | wc -l)" = 4 ]'

step "5. -x: replaces a changed timer, applies it right away, makes no backup"
nBefore=$(sudo ls -d $D/backup_* | wc -l)
sudo sed -i 's/12:00:00/15:00:00/; s/00:00:00/03:00:00/' /etc/minibak.conf
sleep 2
OUT=$(minibak -c default -x 2>&1)
echo "$OUT" | grep -E 'unit|hanges|enabled|disabled|daemon'
chk "-x says the service is unchanged" 'echo "$OUT" | grep -q "No changes to minibak.service"'
chk "-x replaced the timer" 'echo "$OUT" | grep -q "Replacing the minibak.timer"'
chk "installed timer file has the new times" 'systemctl cat minibak.timer | grep -q "03:00:00" && systemctl cat minibak.timer | grep -q "15:00:00"'
chk "the RUNNING timer already uses the new schedule" 'systemctl list-timers minibak.timer --no-pager | grep -q -E " (03|15):00:00 "'
chk "-x made no backup" '[ "$(sudo ls -d $D/backup_* | wc -l)" = "$nBefore" ]'
sudo sed -i 's/15:00:00/12:00:00/; s/03:00:00/00:00:00/' /etc/minibak.conf
minibak -c default -x >/dev/null 2>&1
chk "schedule is back to 00:00 / 12:00 after reverting" 'systemctl list-timers minibak.timer --no-pager | grep -q -E " (00|12):00:00 "'
sudo sed -i 's/^\([[:space:]]*\)bool_timerEnabled=.*/\1bool_timerEnabled=false/' /etc/minibak.conf
minibak -c default -x >/dev/null 2>&1
chk "bool_timerEnabled=false: timer disabled and stopped" '! systemctl is-enabled --quiet minibak.timer && ! systemctl is-active --quiet minibak.timer'
sudo sed -i 's/^\([[:space:]]*\)bool_timerEnabled=.*/\1bool_timerEnabled=true/' /etc/minibak.conf
minibak -c default -x >/dev/null 2>&1
chk "bool_timerEnabled=true: timer enabled and running again" 'systemctl is-enabled --quiet minibak.timer && systemctl is-active --quiet minibak.timer'
chk "main log has no ERROR / FAILURE lines" '! sudo grep -q -E "\[(ERROR|FAILURE)\]" /var/log/minibak.log'

step "6. option handling"
OUT=$(minibak -h 2>&1); rc=$?
chk "-h prints usage, exit 0" '[ $rc -eq 0 ] && echo "$OUT" | grep -q "^Usage:"'
OUT=$(minibak -s 2>&1); rc=$?
chk "-s without argument: error, exit 1" '[ $rc -eq 1 ] && echo "$OUT" | grep -q "needs an argument"'
OUT=$(minibak -q 2>&1); rc=$?
chk "unknown option: usage, exit 1" '[ $rc -eq 1 ] && echo "$OUT" | grep -q "^Usage:"'
OUT=$(minibak -c /nonexistent 2>&1); rc=$?
chk "-c with a missing file: error, exit 1" '[ $rc -eq 1 ] && echo "$OUT" | grep -q "does not exist"'

step "7. uninstall, run 1 (continue=y, rsync=n, logs=n, config=n, tmp=n) while a 20s job is running"
sudo cat /var/log/minibak.log > minibak-final.log
sudo sed -i 's|^ExecStart=.*|ExecStart=/bin/sleep 20|' /etc/systemd/system/minibak.service
sudo systemctl daemon-reload
sudo systemctl start minibak.service --no-block
sleep 1
t0=$(date +%s)
printf 'y\nn\nn\nn\nn\n' | ./install.sh uninstall
t1=$(date +%s)
echo "uninstall took $((t1-t0))s"
chk "uninstall waited for the running job (15s or more)" '[ $((t1-t0)) -ge 15 ]'
chk "script removed" 'test ! -e /usr/bin/minibak'
chk "service unit file removed" 'test ! -e /etc/systemd/system/minibak.service'
chk "timer unit file removed" 'test ! -e /etc/systemd/system/minibak.timer'
chk "timer no longer listed" '! systemctl list-timers --all --no-pager | grep -q minibak'
chk "config + template still there" 'test -f /etc/minibak.conf && test -f /etc/minibak.conf.template'
chk "log still there" 'test -f /var/log/minibak.log'
chk "rsync still installed" 'command -v rsync'
chk "backups untouched" '[ "$(sudo ls -d $D/backup_* | wc -l)" -gt 0 ]'

step "8. uninstall, run 2 (yes to everything, mostly warnings expected)"
printf 'y\ny\ny\ny\ny\n' | ./install.sh uninstall
chk "log removed" 'test ! -e /var/log/minibak.log'
chk "config + template removed" 'test ! -e /etc/minibak.conf && test ! -e /etc/minibak.conf.template'
chk "/tmp/minibak removed" 'test ! -d /tmp/minibak'
chk "rsync removed" '! command -v rsync'
chk "uninstall.log has warnings for already removed things" 'grep -q "\[WARNING\]" uninstall.log'
chk "uninstall.log has no ERROR" '! grep -q "\[ERROR\]" uninstall.log'
chk "backups still untouched" '[ "$(sudo ls -d $D/backup_* | wc -l)" -gt 0 ]'

cp conf.orig conf && rm conf.orig
echo; echo "================ RESULT: $P passed, $F failed ================"
for f in "${FAILS[@]}"; do echo "  FAILED: $f"; done
echo "saved: vmtest.log (this output), install.log, uninstall.log, minibak-final.log"
