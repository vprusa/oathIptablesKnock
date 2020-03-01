#!/bin/bash
THIS_DIR=`dirname $0`

GEN_NEW_HASHES=false
PORT_OFFSET=10000
# max 65535 - $PORT_LIMIT
PORT_LIMIT=1000
USER_HOME=$(eval echo "~$USER")

# p -> for printing ports
# i -> for info messages
# d -> for debug messages
#DEBUG=pc
DEBUG=p

# for testing purposes
SUDO_PREFIX=""
OLD_PORTS=()

# create port generators
PORTS_COUNT=3

KNOCK_FILES_PATH=${USER_HOME}/oathKnock/.google-authenticator-iptables-knock-
RULE_NAME="PRIMARY_KNOCK"
RULE_SNIPPET="-R ${RULE_NAME}{INDEX} {LINE_NMB} -p {PROTOCOL} --dport {PORT} -m recent --name ${RULE_NAME}{INDEX} --set -j DROP"

function usage() {
  printf "Usage: \n\
  \t This script modifies ports for iptables knocking to allow ssh access.\n
  \t --knockFiles=<path> \t-- overrides \$KNOCK_FILES_PATH, its suffix is index of knock\n
  \t -g -- set \$GEN_NEW_HASHES flag so if used generates new keys so as result you have to copy them to client \n
  \t --ports=<int> \t -- overrides \$PORTS_COUNT, changing depends on iptables rules \n
  \t --portOffset=<int> \t-- overrides \$PORT_OFFSET \n
  \t --portLimit=<int> \t -- overrides \$PORT_LIMIT \n"
  1>&2; exit 1;
}

function parseArgs {
  while getopts "hg-:" o; do
    case "${o}" in
      h)
        usage
        ;;
      g)
        GEN_NEW_HASHES=true
        ;;
      -)
        case "${OPTARG}" in
          help)
            usage
            ;;
          knockFiles=*)
            KNOCK_FILES_PATH="${OPTARG/knockFiles=/}"
            ;;
          *)
            usage
            ;;
        esac;;
      *)
        usage
        ;;
    esac
  done
  shift $((OPTIND-1));
}

# this is the main method that runs everything
function run() {
  parseArgs "$@"
  genNewFiles
  loopGeneratingPorts
}

function genNewFiles() {
  if [ $GEN_NEW_HASHES == true ] ; then
    [[ $DEBUG == *"i"* ]] && echo "Genrating oath"
    for i in $(seq 1 $PORTS_COUNT) ; do
      KNOCK_FILE=${KNOCK_FILES_PATH}${i}
      rm -rf ${KNOCK_FILE}
      res=$(printf "y\ny\n\n" | google-authenticator -t -D -S 30 -s ${KNOCK_FILE} -q --no-rate-limit)
      printf "New auth files at: ${KNOCK_FILE}\n"
    done
  fi
}

function loopGeneratingPorts() {
  while true; do
    PORTS=()
    msg=""
    [[ $DEBUG == *"d"* ]] && printf "Generating codes:\n"
    for i in  $(seq 1 $PORTS_COUNT); do
      KNOCK_FILE=${KNOCK_FILES_PATH}${i}
      HASH=$( head -n 1 ${KNOCK_FILE} )
      CODE=$(oathtool --base32 --totp "${HASH}")
      msg="${msg}"$(printf "Knock $i: ${CODE}")
      # remove leading zeros to prepare CODE for modulo
      #NEW_CODE=${CODE##+(0)} # not working in script
      NEW_CODE=$(echo $CODE | sed 's/^0*//')
      CODE=${NEW_CODE}
      #printf "\nNEW_CODE: $NEW_CODE\n"
      RAND_PORT=$((${CODE} % ${PORT_LIMIT}))
      msg="${msg}"$(printf " -> ${RAND_PORT}")
      RAND_OFFSETTED_PORT=$(( ${RAND_PORT} + ${PORT_OFFSET} ))
      msg="${msg}"$(printf " ( ${RAND_OFFSETTED_PORT} )\n")"\n"
      PORTS+=("${RAND_OFFSETTED_PORT}")
    done
    [[ -z "$OLD_PORTS" || ${PORTS[@]} != ${OLD_PORTS[@]} && $DEBUG == *"p"* ]] && printf "${msg}"

    [[ $DEBUG == *"d"* ]] && printf "Ports: ${PORTS[*]}\n"
    [[ $DEBUG == *"d"* ]] && printf "OLD_PORTS: ${OLD_PORTS[*]}\n"
    # if array equals
    if [[ ${PORTS[@]} == ${OLD_PORTS[@]} ]] ; then
      [[ $DEBUG == *"d"* ]] && printf "Same values -> NOT changing\n"
    else
      [[ $DEBUG == *"d"* ]] && printf "\n"
      for i in  $(seq 1 $PORTS_COUNT); do
        KNOCK_NAME=${RULE_NAME}${i}
        PORT_IDNEX=$((${i} - 1))
        NEW_PORT=${PORTS[$PORT_IDNEX]}
        while read  -r line ; do
          #printf "$line"
          lineNmb=$(echo $line | cut -f1 -d' ')
          newRuleSnippet="${RULE_SNIPPET}"
          newRuleSnippet=${newRuleSnippet/'{PORT}'/${NEW_PORT}}
          newRuleSnippet=${newRuleSnippet/'{INDEX}'/${i}}
          newRuleSnippet=${newRuleSnippet/'{INDEX}'/${i}}
          newRuleSnippet=${newRuleSnippet/'{LINE_NMB}'/${lineNmb}}

          if [[ $line == *"tcp"* ]] ; then
            newRuleSnippet=${newRuleSnippet/'{PROTOCOL}'/'tcp'}
          elif [[ $line == *"udp"* ]] ; then
            newRuleSnippet=${newRuleSnippet/'{PROTOCOL}'/'udp'}
          fi

          [[ $DEBUG == *"d"* ]] && printf "newRuleSnippet: "
          [[ $DEBUG == *"d"* ]] && echo "${newRuleSnippet}"
          REPLACE_CMD="${SUDO_PREFIX} iptables ${newRuleSnippet}"
          ${REPLACE_CMD}
        done < <( ${SUDO_PREFIX} iptables -vnL $KNOCK_NAME --line-numbers | grep "SET name: $KNOCK_NAME" )
        OLD_PORTS=("${PORTS[@]}")
      done
    fi
    # TODO use hook to wait for new key instead
    # +-1 sec?
    sleep $((30 - $(date +%s) % 30))
  done
}

run "$@";
