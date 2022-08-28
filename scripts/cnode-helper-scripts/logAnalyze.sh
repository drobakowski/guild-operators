#!/usr/bin/env bash

timestamp() {
  date '+%s' --date="$1";
}

if ! [[ "$#" -gt 1 ]]; then
  echo -e "ERROR: No Arguments provided.\n"
  echo -e "    Usage: ${0} [chain-validation|ledger-replay] <logfile.json>\n" 
  echo -e "    Subcommands:"
  echo -e "        chain-validation		report details about chain validation performance"
  echo -e "        ledger-replay			report details about ledger replay perormance"
else
  subcommand="$1"
  logfile="$2"
  case "${subcommand}" in
    chain-validation )
      unset finalChunk initialChunk startTime endTime percentRemaining currentTime currentHMS totalTime totalHMS
      if [ -z $1 ] ; then
        echo "no file provided as argument"
      else    
        finalChunk=($(jq -r '. | select(.data.initialChunk == "0") | .data.finalChunk, .at' ${logfile}))
        if [ -z "${finalChunk}" ] ; then 
          echo "The log file does not contain an initialChunk 0 in the data. Try another log file."
        else          
          startTime=${finalChunk[1]}
          endTime=$(jq -r --arg myfc ${finalChunk[0]} '. | select(.data.initialChunk == $myfc) | .at' ${logfile})
          if [ -z "${endTime}" ] ; then 
            initialChunk=($(jq -s '[ .[] |select(.data.kind == "TraceImmutableDBEvent.StartedValidatingChunk") | .data.initialChunk ] | max ' ${logfile}))
	    initialChunk+=($(jq -r --arg currentChunk ${initialChunk[0]} '. |select(.data.kind == "TraceImmutableDBEvent.StartedValidatingChunk") | select((.data.initialChunk|tonumber) == ($currentChunk|tonumber)) | .at' ${logfile}))
	    percentageRemaining=$(jq -n 100-${currentChunk[0]}/${finalChunk[0]}*100)
            currentTime=$( echo $(( $(timestamp ${currentChunk[1]}) - $(timestamp ${startTime}) )) )  
            currentHMS=$(date -d@${currentTime} -u +%H:%M:%S)
            echo "${FG_RED}*** Chain Validation Incomplete ***${NC}"
            echo "---------------------------------------------"
	    echo "--- Final Validation Chunk: ${finalChunk[0]}"
	    echo "--- Validation Start Time: ${startTime}"
	    echo "--- Current Chunk: ${initialChunk[0]}"
	    echo "--- Current Chunk Started: ${initialChunk[1]}"
            echo "--- Elapsed Time: ${currentHMS}"
            echo "--- Percent Remaining: ${percentRemaining}"
            echo "---------------------------------------------"
          else                
            totalTime=$( echo $(( $(timestamp ${endTime}) - $(timestamp ${startTime}) )) ) 
            totalHMS=$(date -d@${totalTime} -u +%H:%M:%S)
	    echo -e "${FG_GREEN}*** Chain Validation Complete ***${NC}"
            echo "---------------------------------------------"
	    echo "--- Final Validation Chunk: ${finalChunk[0]}"
	    echo "--- Validation Start Time: ${startTime}"
	    echo "--- Final Chunk Started: ${endTime}"
            echo "--- Total Time: ${totalHMS}"
            echo "---------------------------------------------"
          fi                  
        fi            
      fi      
      ;;
    ledger-replay )
      unset tip slot startTime endTime percentRemaining currentTime currentHms totalTime totalHMS
      tip=($(jq -r '. |select(.data.kind == "TraceLedgerReplayEvent.ReplayedBlock") |select(.data.slot == 0) | .data.tip, .at' ${logfile} ))
      if [ -z "${tip}" ] ; then
        echo "The log file does not contain ReplayedBlock from slot 0 to guage the start time. Try another log file."
      else    
        startTime=${tip[1]}
        endTime=$(jq -r '. |select(.data.kind == "TraceLedgerReplayEvent.ReplayedBlock") |select(.data.slot == .data.tip) | .at' ${logfile} )
        if [ -z "${endTime}" ] ; then
          slot=($(jq -s '[ .[] | select(.data.kind == "TraceLedgerReplayEvent.ReplayedBlock")| .data.slot ] |max ' ${logfile}))
          slot+=($(jq -r --arg currentSlot ${slot[0]} '. | select(.data.kind == "TraceLedgerReplayEvent.ReplayedBlock")| select(.data.slot == ($currentSlot|tonumber)) .at' ${logfile}))
          percentRemaining=$(jq -n 100-${slot[0]}/${tip[0]}*100)
          currentTime=$( echo $(( $(timestamp ${slot[1]}) - $(timestamp ${startTime}) )) )  
          currentHMS=$(date -d@${currentTime} -u +%H:%M:%S)
          echo -e "${FG_RED}*** Ledger Replay Incomplete***${NC}"
          echo "-------------------------------------------"
          echo "--- Tip of the chain: ${tip[0]}"
          echo "--- Start Time: ${tip[1]}"
          echo "--- Most Recent Slot: ${slot[0]}"
          echo "--- Slot Time: ${slot[1]}"
          echo "--- Slots Remaining: $(( ${tip[0]} - ${slot[0]} ))"
          echo "--- Elapsed Time: ${currentHMS}"
          echo "--- Percent Remaining: ${percentRemaining}"
          echo "-------------------------------------------"
        else
          totalTime=$( echo $(( $(timestamp ${endTime}) - $(timestamp ${startTime}) )) )
          totalHMS=$(date -d@${totalTime} -u +%H:%M:%S)
          echo "The total time spent on ledger replay is ${totalHMS}"
        fi            
      fi      
      ;;
      * ) : ;; # ignore
  esac
fi
