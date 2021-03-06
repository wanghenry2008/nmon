#!/bin/sh
DEBUG=false
CHTEL=true
CHPRC=true
CHKKE=true
CHSOL=true
CHNET=true
modified="18.05.2015 16:30"
version=23
starttime="`date +%y%m%d_%H%M`"
sleep 10
reconnectDelay=5
reconnectDelayMultiply=1
second="60"
count="1440"
dir="`readlink -f $0 | xargs dirname`"
hostname="`hostname`"
nmonfile=""
handleNmonfile=""
user="atsdreadonly"
keypath="$HOME/.ssh/id_rsa_atsdreadonly"
port="8081"
parser="default"
sleeptime=10
if [ "$1" = "" -o "`echo $1 | cut -c 1`" = "-" ]; then
    echo "$0: $starttime: first argument must be servername" >> /tmp/nmon_atsd_sender.log
    exit 1
fi
server=$1
shift  1
while getopts "hs:c:m:p:r:f:" opt
do
    case $opt in
        h) 
            echo "Usage: $0 [server] [[arguments]]"
            echo "available arguments :"
            echo "-h                  : show help message"
            echo "-s [second]         : set nmon snapshot frequency ( \"60\" by default )"
            echo "-c [count]          : set amount of snapshots to be taken ( \"1440\" by default )"
            echo "-m [dir]            : set nmon output directory ( "$dir" by default )"
            echo "-p [port]           : set ssh connection port ( \"8081\" by default )"
            echo "-r [parser_id]      : set praser id ( \"default\" by default )"
            echo "-f [file_path]      : set path to nmon file manually"
            exit 1;;
        s) second="$OPTARG";;
        c) count="$OPTARG";;
        m) dir="$OPTARG";;
        u) user="$OPTARG";;
        i) keypath="$OPTARG";;
        p) port="$OPTARG";;
        r) parser="$OPTARG";;
        f) handleNmonfile="$OPTARG";;
    esac
done
if [ ! -d "$dir" ]; then
    echo "$0: $starttime: log directory $dir does not exist" >> /tmp/nmon_atsd_sender.log
    exit 1
fi
logfile="$dir/${hostname}_$starttime.log"

writeLog() { 
    echo "`date +%s-%N` : $1" | tee -a $logfile
}

writeLog "writelog created"
writeLog ""

ctime="`expr \( \`date -u +%Y\` - 1970 \) \* 31536000 + \( \`date -u +%m\` - 1 \) \* 2592000 + \( \`date -u +%d\` - 1 \) \* 86400 + \`date -u +%H\` \* 3600 + \`date -u +%M\` \* 60 + \`date -u +%S\``"
endtime="`expr $count \* $second + $ctime`"

if $DEBUG; then
    writeLog "starting. script pid: $$"
    writeLog "starting from directory `pwd` by user $USER"
    writeLog "working directory: $dir"
    writeLog "`lsb_release -a 2>&1`"  
    writeLog "`cat /etc/*release 2>&1`"
    writeLog "version: $version, modified: $modified"
fi

if $CHTEL; then
if [ "`telnet -h 2>&1 | grep "found"`" != "" ]; then
    writeLog "ERROR. telnet not found."
    exit 1
fi
fi
writeLog "telnet utility found."

if $DEBUG; then
    writeLog "telnet found"
    writeLog "curent timestamp: $ctime"
    writeLog "execute until $endtime"
    writeLog "all process:"
    writeLog "nmon: \r\n`ps -ef | grep "nmon"`"
    writeLog "telnet: \r\n`ps -ef | grep "telnet"`"
fi

if $CHPRC; then
stm="`date +%H:%M`"
if [ "`ps -ef | grep "$0" | awk '{if (index($5, a) == 0) print $0; }' a="$stm"  | wc -l`" -gt "3" ]; then 
    writeLog "process list:\r\n`ps -ef | grep "$0"`"
    writeLog "ERROR. (script count limit reached)"
    exit 1
fi
fi

writeLog "process count check finished"
trap 'endtime=0' TERM
trap 'endtime=0' INT  

killproc() {
    writeLog "starting to kill process with pid:$1, name: $2"
    pid="$1"
    pname="$2"
    if [ "$pid" != "" -a "$pname" != "" ]; then
        if [ "`ps -p $pid | grep "$pname"`" = "" ]; then
            writeLog "process $pname with pid $pid not found(already dead?)"
            sleep 1
        else
            kill -9 $pid
            sleep 1
            if [ "`ps -p $pid | grep "$pname"`" = "" ]; then
                writeLog "process $pname with pid $pid killed"
            sleep 1
            else
                sleep 1
                writeLog "process $pname with pid $pid cannot be killed"
            fi
        fi
    else
        writeLog "cannot kill process with pid: $pid, name: $name"
    fi
}

checkConnectionExist() {
    if [ "`ps -p $telnetpid 2>/dev/null | tail -n 1 | grep telnet`" != "" ]; then
        return 0
    else
        tl="`ps -p $tailpid 2>/dev/null | tail -n 1 | grep tail`"
        tn="`ps -p $telnetpid 2>/dev/null | tail -n 1 | grep telnet`"
        if [ "$tl" != "" -a "$tn" != "" ]; then
            return 0
        else
            if $DEBUG; then
            writeLog "tail or telnet failed."
            writeLog "tail check result:"
            writeLog "$tl"
            writeLog "telnet check result:"
            writeLog "$tn"
            fi
            killproc $telnetpid "telnet"
            killproc $tailpid "tail"
            return 1
        fi
    fi
}
writeLog "functions defined"

if [ "$handleNmonfile" = "" ]; then
    nmonfile=""
    i="0"
    writeLog "checking nmon file by date *_${starttime}.nmon"
    while [ "$i" -lt "3" ]; 
    do
        nmonfile="$dir/${hostanme}_${starttime}.nmon"
        if [ ! -f $nmonfile ]; then
        	nmonfile=""
            nmonfile="`find $dir -type f -name "*_${starttime}.nmon" | grep -i "${hostname}"`"
        else
        i="3"
        break
        fi
        
        if [ "$nmonfile" != "" ]; then
           writeLog "found nmonfile $nmonfile"
            i="3"
            break
        fi
        writeLog "wait for 5 sec. Iteration $i/3"
        sleep 5
        i="`expr $i + 1`"
    done
else
    nmonfile="$handleNmonfile"
fi

writeLog "nmonfile path: $nmonfile"

if [ ! -f "$nmonfile" -o "$nmonfile" = "" ]; then
    if [ "$handleNmonfile" = "" ]; then
        writeLog "ERROR. Could not find nmon file with name $hostname_${starttime}.nmon in $dir:"
        writeLog "`ls -la $dir | tail -n 10 | awk '{print $9}'`"
    else
        writeLog "ERROR. Could not find nmon file by specified name: $nmonfile."
    fi
    exit 1
fi

if $CHSOL; then
    if [ "`cat /etc/*release 2>/dev/null | grep -i "solaris"`" = "" ]; then
       hdr="nmon p:$parser e:${hostname} f:`basename $nmonfile` z:`date +%Z` v:$version"
    else
        writeLog "solaris os determined."
        hdr="nmon p:$parser e:${hostname} f:`basename $nmonfile | cut -c 3-31` z:`date +%Z` v:$version"
    fi
fi


writeLog "starting to work with senderPID: $$, $0 $server $@, FILENAME: $nmonfile"

if $DEBUG; then
    writeLog "nmon command: $hdr"
fi

{ echo "$hdr"; tail -n +0 -f $nmonfile 2>$logfile.tail& echo "$!">${dir}/tailpid; } | telnet $server $port >>$logfile.telnet 2>&1 &
telnetpid="$!"
sleep 1
tailpid="`cat ${dir}/tailpid`"
rm -r ${dir}/tailpid
hdrcount="`grep -n ZZZZ $nmonfile | head  -n 1 | cut -d':' -f1`"
hdrcount="`expr $hdrcount - 1`"
fheader="`head -n $hdrcount $nmonfile`"
writeLog "initial connection established. tailpid: $tailpid, telnetpid: $telnetpid, port: $port"

while [ "$ctime" -lt "$endtime" ]; do
    checkConnectionExist
    conEx=$?
    case "$conEx" in
        "1") waitReconnect=`expr $reconnectDelay \* $reconnectDelayMultiply`
             reconnectDelayMultiply=`expr $reconnectDelayMultiply + 1`
             writeLog "telnet or tail failed, start new telnet after $waitReconnect seconds"
             sleep $waitReconnect
             { echo "$hdr"; echo "$fheader"; tail -n 0 -f $nmonfile& echo "$!" >${dir}/tailpid; } | telnet $server $port >>$logfile 2>&1 &
             telnetpid="$!"
             sleep 1
             tailpid="`cat ${dir}/tailpid`"
             rm -r ${dir}/tailpid
             writeLog "repeat connect established. tailpid: $tailpid, telnetpid: $telnetpid, port: $port"
             sleep $sleeptime 
             ctime="`expr \( \`date -u +%Y\` - 1970 \) \* 31536000 + \( \`date -u +%m\` - 1 \) \* 2592000 + \( \`date -u +%d\` - 1 \) \* 86400 + \`date -u +%H\` \* 3600 + \`date -u +%M\` \* 60 + \`date -u +%S\``"
            ;;
        "0") econnectDelayMultiply=1
             sleep $sleeptime 
             ctime="`expr $ctime + $sleeptime`"
            ;;
    esac
done


writeLog "sending completed"

writeLog "killing $telnetpid"
killproc $telnetpid "telnet"

writeLog "killing $tailpid"
killproc $tailpid "tail"

if [ "$endtime" != "0" ]; then
    writeLog "Done. (by schedule)"
else
    writeLog "ERROR. (interrupt)"
fi
exit 0
