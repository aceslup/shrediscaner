#!/bin/bash
#

HOST="$1"
PORT="$2"
ACT="$3"
PATTERN="$4"
PASS="$5"

if [ $# -lt 4 ]; then
    cat <<EOF
Usage:
  $0 <Host> <Port> <ACT> <Pattern> [pass]

ACT Options:
  expire  # 设置失效时间 (1-9s随机)
  unlink  # 异步清理
  del     # 同步清理

Example:
  $0 127.0.0.1 6379 DEL "prefix_*" mypass

EOF
    exit 1
fi

case $(echo ${ACT}|tr 'a-z' 'A-Z') in
    "EXPIRE" )
        FUNC=_EXPIRE ;;
    "UNLINK" )
        FUNC=_UNLINK ;;
    "DEL" )
        FUNC=_DEL ;;
    * )
        echo "Unsupport Action. Please choose 1 of 3: [EXPIRE,UNLINK,DEL]"
        exit 1
esac

if [ -n "${PASS}" ]; then
    AUTH="-a ${PASS}"
else
    AUTH=""
fi

OPTS="-h ${HOST} -p ${PORT} ${AUTH} --raw --no-auth-warning"
MATCH_KEYS="${HOST}_${PORT}.keys"

CLI="/usr/bin/redis-cli"
LOGFILE="info.log"
PREFIX="cutdata_"   # 切割后文件名前缀

SPLIT_FILE() {
    LINE=100000		  # 每多少行切一刀
    NUM_SUFFIX=0	  # 切割后文件由数字编号, 默认由0开始
    SUFFIX_LEN=3	  # 数字编号长度
    SUFFIX=".txt"	  # 切割后文件扩展名

    START=$(date +%s)
    echo "BEGIN: $(date --date="@${START}" +%"F %T"), FORMAT: ${PREFIX}*${SUFFIX}" |\
        tee -a ${LOGFILE}
    split --lines=${LINE} \
        --numeric-suffixes=${NUM_SUFFIX} \
        --suffix-length=${SUFFIX_LEN} \
        --additional-suffix=${SUFFIX} \
        ${MATCH_KEYS} \
        ${PREFIX}
    END=$(date +%s)
    echo -e "--END: $(date --date="@${END}" +%"F %T"), FILE SPLIT COST TIME: $((${END}-${START}))s\n" |\
        tee -a ${LOGFILE}
}

SCAN_KEY() {
    START=$(date +%s)
    echo "BEGIN: $(date --date="@${START}" +%"F %T"), FILE: ${MATCH_KEYS}" |\
        tee -a ${LOGFILE}
    ${CLI} ${OPTS} --scan --pattern "${PATTERN}" > ${MATCH_KEYS}
    END=$(date +%s)
    KEYS=$(wc -l ${MATCH_KEYS}|awk '{print $1}')
    echo -e "--END: $(date --date="@${END}" +%"F %T"), MATCH KEYS: ${KEYS}, SCAN COST TIME: $((${END}-${START}))s\n" |\
        tee -a ${LOGFILE}
}

_EXPIRE() {
    FILE=$1
    awk -v TIME=$((RANDOM%9+1)) '{printf "*3\r\n$6\r\nEXPIRE\r\n$%s\r\n%s\r\n$1\r\n%d\r\n", length($0), $0, TIME}' ${FILE} |\
         ${CLI} ${OPTS} --pipe
}

_UNLINK() {
    FILE=$1
    awk '{printf "*2\r\n$6\r\nUNLINK\r\n$%s\r\n%s\r\n", length($0), $0}' ${FILE} |\
         ${CLI} ${OPTS} --pipe
}

_DEL() {
    FILE=$1
    awk '{printf "*2\r\n$3\r\nDEL\r\n$%s\r\n%s\r\n", length($0), $0}' ${FILE} |\
         ${CLI} ${OPTS} --pipe
}

RESP_ACT() {
    START=$(date +%s)
    echo "BEGIN: $(date --date="@${START}" +%"F %T"), ACTION: $(echo ${FUNC})" |\
        tee -a ${LOGFILE}
    for FILE in $(ls ${PREFIX}*); do
        echo "$(date +"%F %T"): Loading ${FILE}"
        ${FUNC} ${FILE}
    done |tee -a ${LOGFILE}
    END=$(date +%s)
    KEYS=$(wc -l ${MATCH_KEYS}|awk '{print $1}')
    echo -e "--END: $(date --date="@${END}" +%"F %T"), MATCH KEYS: ${KEYS}, $(echo ${FUNC}) COST TIME: $((${END}-${START}))s\n" |\
        tee -a ${LOGFILE}
}

MAIN() {
    # 创建并进入工作目录
    WORKSPACE=$(mktemp -d match.XXX) && cd ${WORKSPACE}/ && pwd
    touch ${LOGFILE}

    # 扫描出要清理的KEYS
    SCAN_KEY

    # 对KEYS分批
    [ -s ${MATCH_KEYS} ] && SPLIT_FILE

    # 进行清理
    TAG=$(ls ${PREFIX}_${SUFFIX} 2>/dev/null)
    [ -n ${TAG} ] && RESP_ACT ${ACT}
}

MAIN
