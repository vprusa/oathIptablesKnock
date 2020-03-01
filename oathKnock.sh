#!/bin/bash
#sudo yum installgoogle-authenticator oathtool -y
THIS_DIR=`dirname $0`
shopt -s expand_aliases

SERVER="example.com"
SSH_CMD="ssh -v ${USER}@${SERVER}"
TIMEOUT_SSH_TIME=2
TIMEOUT_SSH_CMD="timeout ${TIMEOUT_SSH_TIME} ${SSH_CMD}"
PORT_OFFSET=10000

USE_TRY_FROM=false
TRY_FROM_TIME=`date`

# max 65535
PORT_LIMIT=1000
PROTOCOL=tcp
#PROTOCOL=udp

# create port generators
PORTS_COUNT=3
#KNOCK_FILES_PATH=~/.ssh/.google-authenticator-iptables-knock-
KNOCK_FILES_PATH=${THIS_DIR}/.google-authenticator-iptables-knock-

function usage() {
  printf "Usage:\n
  \t--help -- prints this message\n
  \t--now=<time>\t-- value of oathtool's '--now' parameter \n
  \t--keyFiles=<filesPath> -- as suffix is used port index \n
  \t--ports=<[int]*]> -- list of ports that will be used as static\n
  \t--portsCount=<int> -- count of ports (default 3)\n
  \t--server=<server>\n
  \t--user=<sshUser>\n
  \t-r|--retry=[true|false]\n
  \t--protocol=[tcp|udp] -- default is tcp, but for this may network mess packets\n
  \t--sshCmd=<sshCmd>\n" 1>&2; exit 1;
}

function parseArgs {
  while getopts "h-:" o; do
    case "${o}" in
      h)
        usage
        ;;
      r)
        USE_TRY_FROM=true
        ;;
      -)
        case "${OPTARG}" in
          help)
            usage
            ;;
          now=*)
            TRY_FROM_TIME=${OPTARG/now=/}
            ;;
          retry=*)
            USE_TRY_FROM=${OPTARG/retry=/}
            ;;
          portsCount=*)
            PORTS_COUNT="${OPTARG/portsCount=/}"
            ;;
          keyFiles=*)
            KNOCK_FILES_PATH="${OPTARG/keyFiles=/}"
            ;;
          user=*)
            USER="${OPTARG/user=/}"
            ;;
          protocol=*)
            PROTOCOL="${OPTARG/protocol=/}"
            ;;
          ports=*)
            PORTS_S="${OPTARG/ports=/}"
            IFS=' ' read -ra PORTS_S <<< "$PORTS_S"
            ;;
          server=*)
            SERVER=${OPTARG/server=/}
            #printf "server: ${SERVER}\n"
            ;;
          sshCmd=*)
            # TODO fix order dependent parameters
            SSH_CMD="${OPTARG/sshCmd=/}"
            #printf "sshCmd: ${SSH_CMD}\n"
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
function run()
{
  parseArgs "$@"
  knockAndSSH
}


function knockAndSSH(){
  #clear
  printf "Generating codes\n"
  COUNTER=0

  while [[ ${COUNTER} -eq 0 ]] || [[ "$USE_TRY_FROM" = true ]] ; do
    #time="Sat 29 Feb 2020 08:29:49 PM CET"
    #NOW=$(date --utc -d '20 min ago' +"%Y-%m-%d %T UTC")
    printf "USE_TRY_FROM: $USE_TRY_FROM\n"
    COUNTER=$(($COUNTER + 1))
    PORTS=()
    echo "COUNTER: $COUNTER"

    NOW=$(date -d "${TRY_FROM_TIME} +${COUNTER} min" )
    echo "NOW: $NOW"
    if [[ -z "${PORTS_S}" ]] ; then
      for i in  $(seq 1 $PORTS_COUNT); do
        KNOCK_FILE=${KNOCK_FILES_PATH}${i}
        HASH=$( head -n 1 ${KNOCK_FILE} )
        printf "Knock $i: "
        CODE=$(oathtool --base32 --totp "${HASH}" --now="${NOW}")
        printf "${CODE}"
        # remove leading zeros to prepare CODE for modulo
        #NEW_CODE=${CODE##+(0)} # not working in script
        NEW_CODE=$(echo $CODE | sed 's/^0*//')
        CODE=${NEW_CODE}
        #printf "\nNEW_CODE: $NEW_CODE\n"
        RAND_PORT=$((${CODE} % ${PORT_LIMIT}))
        printf " -> ${RAND_PORT}"
        RAND_OFFSETTED_PORT=$(( ${RAND_PORT} + ${PORT_OFFSET} ))
        printf " ( ${RAND_OFFSETTED_PORT} )\n"
        PORTS+=("${RAND_OFFSETTED_PORT}")
      done
    else
      PORTS=(${PORTS_S[@]})
    fi

    printf "Ports: ${PORTS[*]}"

    printf "\n"
    for i in  $(seq 1 $PORTS_COUNT); do
      PORT_IDNEX=$((${i} - 1))
      PORT=${PORTS[$PORT_IDNEX]}
      if [[ $PROTOCOL == "tcp" ]] ; then
        KNOCK_CMD="nmap -Pn --host-timeout 201 --max-retries 0 -p ${PORT} ${SERVER}"
      elif [[ $PROTOCOL == "udp" ]] ; then
        KNOCK_CMD="echo '*' | nc -w1 -u ${SERVER} ${PORT}"
      fi
      printf "Executing: ${KNOCK_CMD}\n"
      res=$(eval ${KNOCK_CMD})
    done ;
    if [[ "$USE_TRY_FROM" = true ]]  ; then
      TIMEOUT_SSH_CMD="timeout ${TIMEOUT_SSH_TIME} ${SSH_CMD}"
      sshCmd=${TIMEOUT_SSH_CMD}
    else
      sshCmd=${SSH_CMD}
    fi
    res=$(${sshCmd}) ;
    if [[ $res == "Permission denied" ]] || [[ $res == "Last login" ]] ; then
      echo ${res}
      echo "PORTS: ${PORTS[@]}"
      exit
    fi
    sleep 1;
  done
}

# lets run it with program arguments
run "$@";
