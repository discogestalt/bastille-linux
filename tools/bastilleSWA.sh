#! /usr/bin/sh

# Copyright (C) 2007 Hewlett-Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2
#  $Id: bastilleSWA.sh,v 1.11 2007/06/05 00:02:35 fritzr Exp $

###
### Symbolic Constants
###

SUCCESS=0
FAILURE=1
ERROR=$FAILURE
WARNING=2
EXCLUDE=3

PATH=/usr/bin:/sbin:/usr/sbin:/opt/swa/bin:/opt/sec_mgmt/spc/bin



###
###  Define and export proxy envars for use by SWA or SPC
###

setProxies () {

  proxyArgs=""

  if [[ -n ${PROXY} ]]
  then
     [[ -z ${https_proxy} ]] && export https_proxy=${PROXY}
     [[ -z ${http_proxy} ]] && export http_proxy=${PROXY}
     [[ -z ${ftp_proxy} ]] && export ftp_proxy=${PROXY}
  fi

  [[ -n ${https_proxy} ]] && proxyArgs="-x https_proxy=${https_proxy}"
  [[ -n ${http_proxy} ]] && proxyArgs="${proxyArgs} -x http_proxy=${http_proxy}"
  [[ -n ${ftp_proxy} ]] && proxyArgs="${proxyArgs} -x ftp_proxy=${ftp_proxy}"
}


###
###  Send SWA issue report when exposed SecurityBulletin issues found
###

sendSWAReport () {

   typeset -i errval=$SUCCESS

   ${SWA_EXEC} step report -x report_when_no_issues=false 2>/dev/null
   errval=$?

   if [[ $errval -eq $FAILURE ]]
   then
       print -u2 "ERROR:   SWA/SPC Report creation failed.  /var/opt/swa/swa.log, \n"
       print -u2 "         if present, will report more detail.  You may need a network proxy to reach hp.com."
   fi
   
   return $errval
}



###
###  Determine if SWA identifies Security Bulletin-related issues
###

run_swa () {

   typeset -i errval=$SUCCESS
   typeset -i retval=$SUCCESS

   SWA_ANALYSIS_FILE=~/.swa/cache/swa_analysis.xml

   SWA_ANALYZERS=""
   [[ ${SEC_ONLY} -eq 1 ]] && SWA_ANALYZERS="-a SEC"

   typeset -i cntSEC

   setProxies

   ${SWA_EXEC} report -r none ${SWA_ANALYZERS} ${proxyArgs} 2> /dev/null
   errval=$?

   if [[ $errval -ne $FAILURE ]]
   then
       if [[ ! -f ${SWA_ANALYSIS_FILE} || ! -r ${SWA_ANALYSIS_FILE} ]]
       then
           errval=$FAILURE
           print -u2 "ERROR:   Invalid analysis file: ${SWA_ANALYSIS_FILE}"
       else
           cntSEC=$(grep -e "<issue id=\"SEC:" ${SWA_ANALYSIS_FILE} |\
           cut -d: -f1,2 | sort -u | wc -l)

           [[ $cntSEC -gt 0 || ${SEC_ONLY} -ne 1 ]] && sendSWAReport
           retval=$?
           [[ $errval -eq $SUCCESS || $retval -eq $FAILURE ]] && \
              errval=$retval
       fi
   else
       print -u2 "ERROR:   Attempted Software Assistant run failed, /var/opt/swa/swa.log, "
       print -u2 "         if present, will provide more detail.  You may need a network proxy to reach hp.com."
   fi

   return $errval
}



run_spc () {
  typeset -i errval=$SUCCESS

  setProxies
  ${SPC_EXEC} -r -d -q -c /var/opt/sec_mgmt/bastille/security_catalog 2>&1
  return $?
}

###
### Main
###

typeset -i errval=$SUCCESS

SWA_EXEC=$(whence swa)
SPC_EXEC=$(whence security_patch_check)
SWA_1_1_LIB="/opt/swa/lib/jar_version"

# Run SWA 1.1 as first choice
if [[ -n ${SWA_EXEC} && -f ${SWA_EXEC} && -x ${SWA_EXEC} && -f ${SWA_1_1_LIB} ]]
then
    run_swa
    errval=$?
    
#Fall back to SPC
elif [[ -n ${SPC_EXEC} && -f ${SPC_EXEC} && -x ${SPC_EXEC} ]]
then
    run_spc
    errval=$?
     if [[ $errval -eq $FAILURE ]]
     then
        print -u2 "ERROR:   Attempted Security-Patch Check Run Failed."
        print -u2 "         You may need a network proxy to reach hp.com."
     fi
else
    print -u2 "ERROR:   Neither Software Assistant(SWA)nor Security Patch Check found,"
    print -u2 "         SWA can be obtained from https://www.hp.com/go/swa."
fi

return $errval
