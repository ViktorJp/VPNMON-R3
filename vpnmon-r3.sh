#!/bin/sh

# VPNMON-R3 v1.9.4 (VPNMON-R3.SH) is an all-in-one script that is optimized to maintain multiple VPN connections and is
# able to provide for the capabilities to randomly reconnect using a specified server list containing the servers of your
# choice. Special care has been taken to ensure that only the VPN connections you want to have monitored are tended to.
# This script will check the health of up to 5 VPN connections on a regular interval to see if monitored VPN conenctions
# are connected, and sends a ping to a host of your choice through each active connection. If it finds that a connection
# has been lost, it will execute a series of commands that will kill that single VPN client, and randomly picks one of
# your specified servers to reconnect to for each VPN client.
# Last Modified: 2026-Apr-26
##########################################################################################

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"
unset LD_LIBRARY_PATH

##-------------------------------------##
## Added by Martinski W. [2026-Apr-13] ##
##-------------------------------------##
[ "$HOME" != "/root" ] && export HOME="/root"
export SCREENDIR="${HOME}/.screen"

#Static Variables - please do not change
version="1.9.4"                                                 # Version tracker
beta=0                                                          # Beta switch
screenshotmode=0                                                # Switch to present bogus info for screenshots
apppath="/jffs/scripts/vpnmon-r3.sh"                            # Static path to the app
logfile="/jffs/addons/vpnmon-r3.d/vpnmon-r3.log"                # Static path to the log
dlverpath="/jffs/addons/vpnmon-r3.d/version.txt"                # Static path to the version file
config="/jffs/addons/vpnmon-r3.d/vpnmon-r3.cfg"                 # Static path to the config file
lockfile="/jffs/addons/vpnmon-r3.d/resetlock.txt"               # Static path to the reset lock file
vr3emails="/jffs/addons/vpnmon-r3.d/vr3emails.txt"              # Static path to email rate limit file
dvpnconfig="/jffs/addons/vpnmon-r3.d/vr3dblvpn.cfg"             # Double-hop config file path
availableslots="1 2 3 4 5"                                      # Available slots tracker
logsize=2000                                                    # Log file size in rows
timerloop=60                                                    # Timer loop in sec
recover=1                                                       # Number of loops to allow for connection recovery
schedule=0                                                      # Scheduler enable y/n
schedulehrs=1                                                   # Scheduler hours
schedulemin=0                                                   # Scheduler mins
autostart=0                                                     # Auto start on router reboot y/n
unboundclient=0                                                 # Unbound bound to VPN client slot#
unboundwgclient=0                                               # Unbound bound to WG client slot#
unboundshowip=0                                                 # Show expanded Unbound VPN IP on UI
ResolverTimer=1                                                 # Timer to give DNS resolver time to settle
vpnping=0                                                       # Tracking VPN Tunnel Pings
refreshserverlists=0                                            # Tracking Automated Custom VPN Server List Reset
monitorwan=0                                                    # Tracking WAN/Dual WAN Monitoring
useovpn=1                                                       # Tracking OVPN Display/Monitoring
usewg=1                                                         # Tracking WG Display/Monitoring
lockactive=0                                                    # Check for active locks
bypassscreentimer=0                                             # Check to see if screen timer can be bypassed
pingreset=500                                                   # Maximum ping in ms before reset
updateskynet=0                                                  # Check for VPN IP whitelisting in Skynet
amtmemailsuccess=0                                              # AMTM Email Success Message Option
amtmemailfailure=0                                              # AMTM Email Failure Message Option
rstspdmerlin=0                                                  # Reset spdMerlin Interfaces Option
timeoutcmd=""                                                   # For "timeout" cmd for "nvram" calls
timeoutsec=""                                                   # For "timeout" cmd for "nvram" calls
timeoutlng=""                                                   # For "timeout" cmd for "nvram" calls
hideoptions=1                                                   # Hide/Show menu options flag
ratelimit=0                                                     # Rate limiting number of emails/houre
vrcnt=0                                                         # Counter for VPN connection recovery
wrcnt=0                                                         # Counter for WG connection recovery
problemvpnslot=0                                                # Temporary holder for problem VPN slot
problemwgslot=0                                                 # Temporary holder for problem WG slot
selectionmethod=0                                               # 0=Random vs 1=sequential slot selection
lowutilspd=100                                                  # Upper limit of Low / Lower Limit of Med RX Utilization Range
medutilspd=250                                                  # Upper Limit of Med / Lower Limit of High RX Utilization Range
lowutilspdup=15                                                 # Upper limit of Low / Lower Limit of Med TX Utilization Range
medutilspdup=25                                                 # Upper Limit of Med / Lower Limit of High TX Utilization Range
bwdisp=1                                                        # Display value for bandwidth/throughput - 1=Average, 2=Total
PINGHOST="8.8.8.8"                                              # Default Primary PING Host
PINGHOST2="1.1.1.1"                                             # Default Secondary PING Host
WCNT=0                                                          # WAN DOWN counter
recoverytimer=10                                                # Time between recovery attempts before declaring WAN-DOWN
wandowntimer=60                                                 # Time between attempts to determine if WAN is available again
reconnecttimer=300                                              # Time allotted to giving router time to stabilize before reconnecting tunnels
loopexit=0                                                      # Switch to determine if the timerloop was exited early
DVPN_ENABLED=0                                                  # Master switch: 1=active 0=disabled
DVPN_TUNNEL1_TYPE="wg"                                          # Tunnel 1 type: wg or ovpn
DVPN_TUNNEL1_SLOT="1"                                           # Tunnel 1 VPN slot number (1-5)
DVPN_TUNNEL1_IF="wgc1"                                          # Tunnel 1 interface (wgN or tun1N)
DVPN_TUNNEL1_TABLE="201"                                        # Tunnel 1 routing table number
DVPN_TUNNEL1_MARK="0x201"                                       # Tunnel 1 fwmark (hex of table)
DVPN_TUNNEL2_TYPE="wg"                                          # Tunnel 2 type: wg or ovpn
DVPN_TUNNEL2_SLOT="2"                                           # Tunnel 2 VPN slot number (1-5)
DVPN_TUNNEL2_IF="wgc2"                                          # Tunnel 2 interface
DVPN_TUNNEL2_TABLE="202"                                        # Tunnel 2 routing table number
DVPN_TUNNEL2_MARK="0x202"                                       # Tunnel 2 fwmark
DVPN_HOP_IPS=""                                                 # Space-separated client IPs/CIDRs/ranges
DVPN_HOP_MARK="0x1CC"                                           # fwmark applied to double-hop clients
DVPN_WG_MAX_AGE=180                                             # Max WG handshake age (sec) before DOWN
DVPN_STATE_FILE="/tmp/doublevpn-state"                          # Runtime state across loop iterations
DVPN_SAVED_RULES="/tmp/doublevpn-saved-rules.txt"               # VPN Director rules suspended by us
DVPN_INSTALLED_IPS_FILE="/tmp/doublevpn-installed-ips"          # Tracks the exact IP entries that had rules
DVPN_LOCK="/tmp/doublevpn.lock"                                 # Mutual-exclusion lock file
DVPN_HOP_PRIO=99                                                # Hop Priority

# To support automatic script updates from AMTM #
doScriptUpdateFromAMTM=true

##-------------------------------------##
## Added by Martinski W. [2024-Oct-05] ##
##-------------------------------------##
readonly IPv4octet_RegEx="([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])"
readonly IPv4addrs_RegEx="(${IPv4octet_RegEx}\.){3}${IPv4octet_RegEx}"
LAN_HostName=""
prevHideOpts=X  # Avoid redisplaying the menu options unnecessarily too often #

## Custom Email Library Notification Variables ##
readonly scriptFileName="${0##*/}"
readonly scriptFileNTag="${scriptFileName%.*}"
readonly CEM_LIB_TAG="master"
readonly CEM_LIB_URL="https://raw.githubusercontent.com/Martinski4GitHub/CustomMiscUtils/${CEM_LIB_TAG}/EMail"
readonly CUSTOM_EMAIL_LIBDir="/jffs/addons/shared-libs"
readonly CUSTOM_EMAIL_LIBName="CustomEMailFunctions.lib.sh"
readonly CUSTOM_EMAIL_LIBFile="${CUSTOM_EMAIL_LIBDir}/$CUSTOM_EMAIL_LIBName"

# Color variables
CBlack="\e[1;30m"
InvBlack="\e[1;40m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CDkGray="\e[1;90m"
InvDkGray="\e[1;100m"
InvLtGray="\e[1;47m"
CYellow="\e[1;33m"
InvYellow="\e[1;43m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
InvCyan="\e[1;46m"
CWhite="\e[1;37m"
InvWhite="\e[1;107m"
CClear="\e[0m"

# -------------------------------------------------------------------------------------------------------------------------
# blackwhite is a simple function that removes all color attributes
blackwhite()
{

CBlack=""
InvBlack=""
CRed=""
InvRed=""
CGreen=""
InvGreen=""
CDkGray=""
InvDkGray=""
InvLtGray=""
CYellow=""
InvYellow=""
CBlue=""
InvBlue=""
CMagenta=""
CCyan=""
InvCyan=""
CWhite=""
InvWhite=""
CClear=""

}

# -------------------------------------------------------------------------------------------------------------------------
# LogoNM is a function that displays the VPNMON-R3 script name in a cool ASCII font without menu options

logoNM () {
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CDkGray}               _    ______  _   ____  _______  _   __      ____ _____"
  echo -e "              | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__  /"
  echo -e "              | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ //_ < "
  echo -e "              | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/__/ / "
  echo -e "              |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ INITIALIZING ]     ${CClear}"
  sleep 2
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CYellow}               _    ______  _   ____  _______  _   __      ____ _____"
  echo -e "              | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__  /"
  echo -e "              | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ //_ < "
  echo -e "              | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/__/ / "
  echo -e "              |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}[ INITIALIZING ... DONE ]${CClear}"
  sleep 1
  printf "\r                            ${CGreen}      [ LOADING... ]     ${CClear}"
  sleep 2
}

logoNMexit () {
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CYellow}               _    ______  _   ____  _______  _   __      ____ _____"
  echo -e "              | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__  /"
  echo -e "              | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ //_ < "
  echo -e "              | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/__/ / "
  echo -e "              |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ SHUTTING DOWN ]     ${CClear}"
  sleep 2
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CDkGray}               _    ______  _   ____  _______  _   __      ____ _____"
  echo -e "              | |  / / __ \/ | / /  |/  / __ \/ | / /     / __ \__  /"
  echo -e "              | | / / /_/ /  |/ / /|_/ / / / /  |/ /_____/ /_/ //_ < "
  echo -e "              | |/ / ____/ /|  / /  / / /_/ / /|  /_____/ _, _/__/ / "
  echo -e "              |___/_/   /_/ |_/_/  /_/\____/_/ |_/     /_/ |_/____/ v$version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ SHUTTING DOWN ]     ${CClear}"
  sleep 1
  printf "\r                            ${CDkGray}      [ GOODBYE... ]     ${CClear}\n\n"
  sleep 2
}

# -------------------------------------------------------------------------------------------------------------------------
# Promptyn is a simple function that accepts y/n input

promptyn()
{   # No defaults, just y or n
  while true; do
    read -p "$1" -n 1 -r yn
      case "${yn}" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer y or n.";;
      esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# Spinner is a script that provides a small indicator on the screen to show script activity

spinner()
{
  spins=$1

  spin=0
  charspin=0
  totalspins=$((spins / 4))
  while [ $spin -le $totalspins ]; do
    for spinchar in / - \\ \|; do
      printf "\r$spinchar ${CGreen}[${CWhite}$charspin${CGreen}]"
      charspin=$((charspin + 1))
      sleep 1
    done
    spin=$((spin+1))
  done

  printf "\r"
}

##-------------------------------------------##
## Borrwed from ExtremeFiretop [2026-Apr-11] ##
##-------------------------------------------##
ScriptUpdateFromAMTM()
{
    if ! "$doScriptUpdateFromAMTM"
    then
        printf "Automatic script updates via AMTM are currently disabled.\n\n"
        return 1
    fi

    if [ $# -gt 0 ] && [ "$1" = "check" ]
    then return 0
    fi

    # Force a BACKUPMON download and update
    echo -e "${CClear}[i] Force Downloading VPNMON-R3... Please stand by..."
    curl --silent --fail --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
    DLsuccess=$?
    if [ "$DLsuccess" -eq 0 ]; then
      echo -e "${CClear}[i] VPNMON-R3 Download/Update Success."
    else
      echo -e "${CClear}[X] VPNMON-R3 Download/Update Failed."
    fi

    return "$DLsuccess"
}

# -------------------------------------------------------------------------------------------------------------------------
# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-01] ##
##----------------------------------------##
preparebar()
{
  barlen="$1"
  barspaces="$(printf "%*s" "$1" ' ')"
  barchars="$(printf "%*s" "$1" ' ' | tr ' ' "$2")"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##

_GetPercent_() { printf "%.1f" "$(awk "BEGIN{print $1}")" ; }
#_GetPercent_() { printf "%.1f" "$(echo "$1" | awk "{print $1}")" ; }

progressbaroverride()
{
  insertspc=" "
  bypasswancheck=0

  if [ "$1" -eq -1 ]
  then
     printf "\r  $barspaces\r"
  else
     if [ $# -gt 6 ] && [ -n "$7" ] && [ "$1" -ge "$7" ]
     then
        barch="$(($7*barlen/$2))"
        barsp="$((barlen-barch))"
        percnt="$(_GetPercent_ "(100*$1/$2)")"
     else
        barch="$(($1*barlen/$2))"
        barsp="$((barlen-barch))"
        percnt="$(_GetPercent_ "(100*$1/$2)")"
     fi

     if [ $# -gt 5 ] && [ -n "$6" ]; then AltNum="$6" ; else AltNum="$1" ; fi

     if [ "$5" = "Standard" ]
     then
        printf "  ${CWhite}${InvDkGray}%3d${4} /%5.1f%%${CClear} [${CGreen}e${CClear}=Exit] [Selection? ${InvGreen} ${CClear}${CGreen}]\r${CClear}" "$AltNum" "$percnt"
     fi
  fi

  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  #key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2 2>/dev/null || echo /dev/null)"

  if [ "$key_press" ]
  then
      case "$key_press" in
          [1]) echo ""; restartvpn 1; dvpn_on_tunnel_restart "ovpn" "1"; sendmessage 0 "VPN Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [2]) echo ""; restartvpn 2; dvpn_on_tunnel_restart "ovpn" "2"; sendmessage 0 "VPN Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [3]) echo ""; restartvpn 3; dvpn_on_tunnel_restart "ovpn" "3"; sendmessage 0 "VPN Reset" 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [4]) echo ""; restartvpn 4; dvpn_on_tunnel_restart "ovpn" "4"; sendmessage 0 "VPN Reset" 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [5]) echo ""; restartvpn 5; dvpn_on_tunnel_restart "ovpn" "5"; sendmessage 0 "VPN Reset" 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [6]) echo ""; restartwg 1; dvpn_on_tunnel_restart "wg" "1"; sendmessage 0 "WG Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [7]) echo ""; restartwg 2; dvpn_on_tunnel_restart "wg" "2"; sendmessage 0 "WG Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [8]) echo ""; restartwg 3; dvpn_on_tunnel_restart "wg" "3"; sendmessage 0 "WG Reset" 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [9]) echo ""; restartwg 4; dvpn_on_tunnel_restart "wg" "4"; sendmessage 0 "WG Reset" 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [0]) echo ""; restartwg 5; dvpn_on_tunnel_restart "wg" "5"; sendmessage 0 "WG Reset" 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\!]) echo ""; killunmonvpn 1; sendmessage 0 "VPN Killed" 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\@]) echo ""; killunmonvpn 2; sendmessage 0 "VPN Killed" 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\#]) echo ""; killunmonvpn 3; sendmessage 0 "VPN Killed" 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\$]) echo ""; killunmonvpn 4; sendmessage 0 "VPN Killed" 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\%]) echo ""; killunmonvpn 5; sendmessage 0 "VPN Killed" 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\^]) echo ""; killunmonwg 1; sendmessage 0 "WG Killed" 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\&]) echo ""; killunmonwg 2; sendmessage 0 "WG Killed" 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\-]) echo ""; killunmonwg 3; sendmessage 0 "WG Killed" 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\+]) echo ""; killunmonwg 4; sendmessage 0 "WG Killed" 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\=]) echo ""; killunmonwg 5; sendmessage 0 "WG Killed" 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [Aa]) autostart;; #resetifacestats;;
          [Cc]) vsetup;; #resetifacestats;;
          [Dd]) wgserverlistautomation;; #resetifacestats;;
          [Ee]) logoNMexit; echo -e "${CClear}\n"; exit 0;;
          [Hh]) hideoptions=1 ; [ "$hideoptions" != "$prevHideOpts" ] && timerreset=1 ;;
          [Ii]) amtmevents;; #resetifacestats;;
          [Ll]) vlogs;; #resetifacestats;;
          [Mm]) vpnslots;; #resetifacestats;;
          [Pp]) maxping;; #resetifacestats;;
          [Rr]) schedulevpnreset;; #resetifacestats;;
          [Ss]) hideoptions=0 ; [ "$hideoptions" != "$prevHideOpts" ] && timerreset=1 ;;
          [Tt]) timerloopconfig;; #resetifacestats;;
          [Uu]) vpnserverlistautomation;; #resetifacestats;;
          [Vv]) vpnserverlistmaint;; #resetifacestats;;
          [Ww]) wgserverlistmaint;; #resetifacestats;;
          [Xx]) uninstallr2;; #resetifacestats;;
             *) ;; ##IGNORE INVALID key presses ##
      esac
      bypasswancheck=1
      loopexit=1
  fi
}

progressbarpause()
{
  insertspc=" "
  bypasswancheck=0

  if [ "$1" -eq -1 ]
  then
     printf "\r  $barspaces\r"
  else
    if [ $# -gt 6 ] && [ -n "$7" ] && [ "$1" -ge "$7" ]
    then
       barch="$(($7*barlen/$2))"
       barsp="$((barlen-barch))"
       progr="$((100*$1/$2))"
    else
       barch="$(($1*barlen/$2))"
       barsp="$((barlen-barch))"
       progr="$((100*$1/$2))"
    fi

    if [ $# -gt 5 ] && [ -n "$6" ]; then AltNum="$6" ; else AltNum="$1" ; fi

    if [ "$5" = "Standard" ]
    then
       printf "  ${CWhite}${InvDkGray}Continuing Reset in $AltNum/5...${CClear} [${CGreen}p${CClear}=Pause] [${CGreen}e${CClear}=Exit] [Selection? ${InvGreen} ${CClear}${CGreen}]\r${CClear}" "$barchars" "$barspaces"
    fi
  fi

  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  #key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2 2>/dev/null || echo /dev/null)"

  if [ $key_press ]
  then
      case $key_press in
          [Pp]) vpause;;
          [Ee]) logoNMexit; echo -e "${CClear}\n"; exit 0;;
      esac
      bypasswancheck=1
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# This function optionally uninstalls VPNMON-R2 if still found present on local router

uninstallr2()
{

if [ -f /jffs/scripts/vpnmon-r2.sh ]
then
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R2 Uninstall Utility                                                           ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This utility allows you to uninstall VPNMON-R2. NOTE: Please know that VPNMON-R2"
  echo -e "${InvGreen} ${CClear} development is ceasing, and product support will be sunset in the very near future."
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} VPNMON-R2 was still found installed on your router. This menu gives you the option"
  echo -e "${InvGreen} ${CClear} to launch (if needed) or uninstall the old legacy VPNMON-R2. Thank you!"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  printf "${CClear}Please select? (${CGreen}u${CClear}=UNinstall R2, ${CGreen}r${CClear}=Run R2, ${CGreen}e${CClear}=Exit)"
  read -p ": " SelectR2
    case $SelectR2 in
      [Uu])
        echo -e "\n${CClear}Please type 'Y' to validate you wish to proceed with the uninstall of VPNMON-R2.${CClear}"
        if promptyn "[y/n]: "
        then
          echo -e "\n${CClear}Uninstalling VPNMON-R2 components...${CClear}"

          if [ "$(cat /jffs/addons/vpnmon-r2.d/vpnmon-r2.cfg | grep "UpdateUnbound" | cut -d '=' -f 2-)" = "1" ]
          then
            # Delete all additions made to files to enable Unbound over VPN functionality
            echo ""
            echo -e "\n${CClear}Unbinding Unbound from VPN..."
            # Disable vpn functionality with Unbound
            sh /jffs/addons/unbound/unbound_manager.sh vpn=disable >/dev/null 2>&1
            # Remove Unbound failsafe in post-mount
            if [ -f /jffs/scripts/post-mount ]; then
              sed -i -e '/vpn=disable/d' /jffs/scripts/post-mount >/dev/null 2>&1
            fi
            # Remove Unbound VPN helper script in openvpn-event
            if [ -f /jffs/scripts/openvpn-event ]; then
              sed -i -e '/unbound_DNS_via_OVPN.sh/d' /jffs/scripts/openvpn-event >/dev/null 2>&1
            fi
            # Remove RPDB Rules added to nat-start
            if [ -f /jffs/scripts/nat-start ]; then
              sed -i -e '/Added by vpnmon-r2/d' /jffs/scripts/nat-start >/dev/null 2>&1
            fi
            # Remove the unbound_DNS_via_OVPN.sh file
            if [ -f /jffs/addons/unbound/unbound_DNS_via_OVPN.sh ]; then
              rm /jffs/addons/unbound/unbound_DNS_via_OVPN.sh
            fi
            echo -e "\n${CClear}If Unbound-over-VPN is enabled on VPNMON-R3, you may need to disable/re-enable"
            echo -e "this feature under the setup/configuration menu again. Conflicts may have"
            echo -e "arisen with both products having this feature enabled."
          fi

          echo -e "\n${CClear}Removing VPNMON-R2 Files..."
          # Remove R2 Files
          rm -f -r /jffs/addons/vpnmon-r2.d
          rm -f /jffs/scripts/vpnmon-r2.sh
          if [ -f /jffs/scripts/post-mount ]; then
            sed -i -e '/vpnmon-r2.sh/d' /jffs/scripts/post-mount >/dev/null 2>&1
          fi
          echo -e "\n${CClear}VPNMON-R2 has been uninstalled...${CClear}"
          echo ""
          read -rsp $'Press any key to continue...\n' -n1 key
          timer="$timerloop"
          echo -e "${CClear}\n"
          return
        else
          timer="$timerloop"
          echo -e "${CClear}\n"
          return
        fi
      ;;

      [Rr]) exec sh /jffs/scripts/vpnmon-r2.sh -setup; exit 0;;
      [Ee]) timer="$timerloop" ; echo -e "${CClear}\n"; return;;

    esac
fi

}

# -------------------------------------------------------------------------------------------------------------------------
# This function presents an Operational Menu in a Pause state, usually during VPN slot errors which give you a 5 second
# opportunity to pause in order to make any particular changes that might help your situation

vpause()
{

while true
do
  if [ "$availableslots" = "1 2" ]
  then
    clear
    displayopsmenu
    printf "${CClear}Please select? (${CGreen}n${CClear}=UNpause, ${CGreen}e${CClear}=Exit)"
    read -p ": " SelectSlot
      case $SelectSlot in
            [1]) echo ""; restartvpn 1; dvpn_on_tunnel_restart "ovpn" "1"; sendmessage 0 "VPN Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [2]) echo ""; restartvpn 2; dvpn_on_tunnel_restart "ovpn" "2"; sendmessage 0 "VPN Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\!]) echo ""; killunmonvpn 1; sendmessage 0 "VPN Killed" 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\@]) echo ""; killunmonvpn 2; sendmessage 0 "VPN Killed" 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [Aa]) autostart;; #resetifacestats;;
            [Cc]) vsetup;; #resetifacestats;;
            [Ee]) echo -e "${CClear}\n"; exit 0;;
            [Ii]) amtmevents;; #resetifacestats;;
            [Ll]) vlogs;; #resetifacestats;;
            [Mm]) vpnslots;; #resetifacestats;;
            [Pp]) maxping;; #resetifacestats;;
            [Rr]) schedulevpnreset;; #resetifacestats;;
            [Tt]) timerloopconfig;; #resetifacestats;;
            [Uu]) vpnserverlistautomation;; #resetifacestats;;
            [Vv]) vpnserverlistmaint;; #resetifacestats;;
            [Nn]) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            *) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
        esac
  elif [ "$availableslots" = "1 2 3 4 5" ]
  then
    clear
    displayopsmenu
    printf "${CClear}Please select? (${CGreen}n${CClear}=UNpause, ${CGreen}e${CClear}=Exit)"
    read -p ": " SelectSlot
      case $SelectSlot in
            [1]) echo ""; restartvpn 1; dvpn_on_tunnel_restart "ovpn" "1"; sendmessage 0 "VPN Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [2]) echo ""; restartvpn 2; dvpn_on_tunnel_restart "ovpn" "2"; sendmessage 0 "VPN Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [3]) echo ""; restartvpn 3; dvpn_on_tunnel_restart "ovpn" "3"; sendmessage 0 "VPN Reset" 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [4]) echo ""; restartvpn 4; dvpn_on_tunnel_restart "ovpn" "4"; sendmessage 0 "VPN Reset" 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [5]) echo ""; restartvpn 5; dvpn_on_tunnel_restart "ovpn" "5"; sendmessage 0 "VPN Reset" 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [6]) echo ""; restartwg 1; dvpn_on_tunnel_restart "wg" "1"; sendmessage 0 "WG Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [7]) echo ""; restartwg 2; dvpn_on_tunnel_restart "wg" "2"; sendmessage 0 "WG Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [8]) echo ""; restartwg 3; dvpn_on_tunnel_restart "wg" "3"; sendmessage 0 "WG Reset" 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [9]) echo ""; restartwg 4; dvpn_on_tunnel_restart "wg" "4"; sendmessage 0 "WG Reset" 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [0]) echo ""; restartwg 5; dvpn_on_tunnel_restart "wg" "5"; sendmessage 0 "WG Reset" 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\!]) echo ""; killunmonvpn 1; sendmessage 0 "VPN Killed" 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\@]) echo ""; killunmonvpn 2; sendmessage 0 "VPN Killed" 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\#]) echo ""; killunmonvpn 3; sendmessage 0 "VPN Killed" 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\$]) echo ""; killunmonvpn 4; sendmessage 0 "VPN Killed" 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\%]) echo ""; killunmonvpn 5; sendmessage 0 "VPN Killed" 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\^]) echo ""; killunmonwg 1; sendmessage 0 "WG Killed" 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\&]) echo ""; killunmonwg 2; sendmessage 0 "WG Killed" 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\-]) echo ""; killunmonwg 3; sendmessage 0 "WG Killed" 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\+]) echo ""; killunmonwg 4; sendmessage 0 "WG Killed" 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\=]) echo ""; killunmonwg 5; sendmessage 0 "WG Killed" 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [Aa]) autostart;; #resetifacestats;;
            [Cc]) vsetup;; #resetifacestats;;
            [Ee]) echo -e "${CClear}\n"; exit 0;;
            [Ii]) amtmevents;; #resetifacestats;;
            [Ll]) vlogs;; #resetifacestats;;
            [Mm]) vpnslots;; #resetifacestats;;
            [Pp]) maxping;; #resetifacestats;;
            [Rr]) schedulevpnreset;; #resetifacestats;;
            [Tt]) timerloopconfig;; #resetifacestats;;
            [Uu]) vpnserverlistautomation;; #resetifacestats;;
            [Vv]) vpnserverlistmaint;; #resetifacestats;;
            [Ww]) wgserverlistmaint;; #resetifacestats;;
            [Nn]) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            *) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
        esac
  fi
done
}

# -------------------------------------------------------------------------------------------------------------------------
# creates needed config files if they don't exist

createconfigs()
{

  # Create initial vr3clients.txt & vr3timers.txt file
  if [ ! -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]
  then
    if [ "$availableslots" = "1 2" ]
    then
      { echo 'VPN1=0'
        echo 'VPN2=0'
      } > /jffs/addons/vpnmon-r3.d/vr3clients.txt

    elif [ "$availableslots" = "1 2 3 4 5" ]
    then
      { echo 'VPN1=0'
        echo 'VPN2=0'
        echo 'VPN3=0'
        echo 'VPN4=0'
        echo 'VPN5=0'
        echo 'WG1=0'
        echo 'WG2=0'
        echo 'WG3=0'
        echo 'WG4=0'
        echo 'WG5=0'
      } > /jffs/addons/vpnmon-r3.d/vr3clients.txt
    fi
  fi

  if [ ! -f /jffs/addons/vpnmon-r3.d/vr3timers.txt ]
  then
    if [ "$availableslots" = "1 2" ]
    then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt

    elif [ "$availableslots" = "1 2 3 4 5" ]
    then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
        echo 'VPNTIMER3=0'
        echo 'VPNTIMER4=0'
        echo 'VPNTIMER5=0'
        echo 'WGTIMER1=0'
        echo 'WGTIMER2=0'
        echo 'WGTIMER3=0'
        echo 'WGTIMER4=0'
        echo 'WGTIMER5=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
    fi
  fi


  if [ "$availableslots" = "1 2 3 4 5" ]
    then
      # Determine if the new Wireguard client values are present, if not, add them
      if ! grep -q "WG" "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
        then
          # Check for and remove empty lines after the last entry before the EOF
          awk 'NF > 0 {for (i=1; i<=b; i++) print ""; b=0; print} NF==0 {b++}' "/jffs/addons/vpnmon-r3.d/vr3clients.txt" > "/jffs/addons/vpnmon-r3.d/vr3clients.tmp"
          # Overwrite the original file with the cleaned-up version.
          mv "/jffs/addons/vpnmon-r3.d/vr3clients.tmp" "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
          # Write the new Wireguard timer values
          cat << EOF >> "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
WG1=0
WG2=0
WG3=0
WG4=0
WG5=0
EOF

      fi

      # Determine if the new Wireguard timer values are present, if not, add them
      if ! grep -q "WGTIMER" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
        then
          # Check for and remove empty lines after the last entry before the EOF
          awk 'NF > 0 {for (i=1; i<=b; i++) print ""; b=0; print} NF==0 {b++}' "/jffs/addons/vpnmon-r3.d/vr3timers.txt" > "/jffs/addons/vpnmon-r3.d/vr3timers.tmp"
          # Overwrite the original file with the cleaned-up version.
          mv "/jffs/addons/vpnmon-r3.d/vr3timers.tmp" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
          # Write the new Wireguard timer values
          cat << EOF >> "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
WGTIMER1=0
WGTIMER2=0
WGTIMER3=0
WGTIMER4=0
WGTIMER5=0
EOF

      fi
  fi

  # Create new DoubleVPN config
  if [ ! -f "$dvpnconfig" ]
  then
    dvpn_saveconfig
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_saveconfig - write vr3dblvpn.cfg to /jffs/addons/vpnmon-r3.d

dvpn_saveconfig()
{
  {
    echo "DVPN_ENABLED=$DVPN_ENABLED"
    echo "DVPN_TUNNEL1_TYPE=\"$DVPN_TUNNEL1_TYPE\""
    echo "DVPN_TUNNEL1_SLOT=\"$DVPN_TUNNEL1_SLOT\""
    echo "DVPN_TUNNEL1_IF=\"$DVPN_TUNNEL1_IF\""
    echo "DVPN_TUNNEL1_TABLE=\"$DVPN_TUNNEL1_TABLE\""
    echo "DVPN_TUNNEL1_MARK=\"$DVPN_TUNNEL1_MARK\""
    echo "DVPN_TUNNEL2_TYPE=\"$DVPN_TUNNEL2_TYPE\""
    echo "DVPN_TUNNEL2_SLOT=\"$DVPN_TUNNEL2_SLOT\""
    echo "DVPN_TUNNEL2_IF=\"$DVPN_TUNNEL2_IF\""
    echo "DVPN_TUNNEL2_TABLE=\"$DVPN_TUNNEL2_TABLE\""
    echo "DVPN_TUNNEL2_MARK=\"$DVPN_TUNNEL2_MARK\""
    echo "DVPN_HOP_IPS=\"$DVPN_HOP_IPS\""
    echo "DVPN_HOP_MARK=\"$DVPN_HOP_MARK\""
    echo "DVPN_WG_MAX_AGE=$DVPN_WG_MAX_AGE"
  } > "$dvpnconfig"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_loadconfig - load vr3dblvpn.cfg if it exists

dvpn_loadconfig()
{
  [ -f "$dvpnconfig" ] && . "$dvpnconfig"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_log - write a timestamped entry to the VPNMON-R3 log and trim

dvpn_log()
{
  # DH = DoubleHop VPN notation in logs
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - DH $*" >> "$logfile"
  # Trim log to logsize lines
  if [ -f "$logfile" ] && [ "$(wc -l < "$logfile")" -gt "$logsize" ]; then
    tail -n "$logsize" "$logfile" > /tmp/dvpn_log_trim.tmp
    mv /tmp/dvpn_log_trim.tmp "$logfile"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_ip_format - detect format of an IP entry
# Output: single | cidr | range | invalid

dvpn_ip_format()
{
  local entry="$1"
  if echo "$entry" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'; then
    echo "cidr"; return
  fi
  if echo "$entry" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "range"; return
  fi
  if echo "$entry" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "single"; return
  fi
  echo "invalid"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_ip_to_int - convert dotted-decimal to 32-bit integer

dvpn_ip_to_int()
{
  local ip="$1"
  local a b c d
  IFS='.' read -r a b c d <<EOF
$ip
EOF
  echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_mangle_rule - add or remove iptables mangle PREROUTING mark rule
# Usage: dvpn_mangle_rule <add|del> <ip_entry> <mark>

dvpn_mangle_rule()
{
  local action="$1" entry="$2" mark="$3"
  local fmt ipt_action
  fmt=$(dvpn_ip_format "$entry")
  [ "$action" = "add" ] && ipt_action="-A" || ipt_action="-D"

  case "$fmt" in
    single|cidr)
      iptables -t mangle $ipt_action PREROUTING \
        -s "$entry" -j MARK --set-mark "$mark" 2>/dev/null
      ;;
    range)
      local start end
      start=$(echo "$entry" | cut -d- -f1)
      end=$(echo "$entry" | cut -d- -f2)
      if lsmod 2>/dev/null | grep -qE "xt_iprange|ipt_iprange"; then
        iptables -t mangle $ipt_action PREROUTING \
          -m iprange --src-range "${start}-${end}" \
          -j MARK --set-mark "$mark" 2>/dev/null
      else
        # iprange module unavailable - expand range to individual rules
        dvpn_log "INFO: iprange module not available, expanding range: $entry"
        local s_int e_int cur ip
        s_int=$(dvpn_ip_to_int "$start")
        e_int=$(dvpn_ip_to_int "$end")
        cur=$s_int
        while [ "$cur" -le "$e_int" ]; do
          ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
          iptables -t mangle $ipt_action PREROUTING \
            -s "$ip" -j MARK --set-mark "$mark" 2>/dev/null
          cur=$(( cur + 1 ))
        done
      fi
      ;;
    *)
      dvpn_log "WARNING: Skipping invalid IP entry '$entry'"
      ;;
  esac
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_mss_rule - add or remove TCPMSS clamping rule for an IP entry
# Usage: dvpn_mss_rule <add|del> <ip_entry> <mss>

dvpn_mss_rule()
{
  local action="$1" entry="$2" mss="$3"
  local fmt ipt_action
  fmt=$(dvpn_ip_format "$entry")
  [ "$action" = "add" ] && ipt_action="-A" || ipt_action="-D"

  case "$fmt" in
    single|cidr)
      iptables -t mangle $ipt_action FORWARD \
        -s "$entry" -p tcp --tcp-flags SYN,RST SYN \
        -j TCPMSS --set-mss "$mss" 2>/dev/null
      iptables -t mangle $ipt_action FORWARD \
        -d "$entry" -p tcp --tcp-flags SYN,RST SYN \
        -j TCPMSS --set-mss "$mss" 2>/dev/null
      ;;
    range)
      local start end
      start=$(echo "$entry" | cut -d- -f1)
      end=$(echo "$entry" | cut -d- -f2)
      if lsmod 2>/dev/null | grep -qE "xt_iprange|ipt_iprange"; then
        iptables -t mangle $ipt_action FORWARD \
          -m iprange --src-range "${start}-${end}" \
          -p tcp --tcp-flags SYN,RST SYN \
          -j TCPMSS --set-mss "$mss" 2>/dev/null
        iptables -t mangle $ipt_action FORWARD \
          -m iprange --dst-range "${start}-${end}" \
          -p tcp --tcp-flags SYN,RST SYN \
          -j TCPMSS --set-mss "$mss" 2>/dev/null
      else
        local s_int e_int cur ip
        s_int=$(dvpn_ip_to_int "$start")
        e_int=$(dvpn_ip_to_int "$end")
        cur=$s_int
        while [ "$cur" -le "$e_int" ]; do
          ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
          iptables -t mangle $ipt_action FORWARD \
            -s "$ip" -p tcp --tcp-flags SYN,RST SYN \
            -j TCPMSS --set-mss "$mss" 2>/dev/null
          iptables -t mangle $ipt_action FORWARD \
            -d "$ip" -p tcp --tcp-flags SYN,RST SYN \
            -j TCPMSS --set-mss "$mss" 2>/dev/null
          cur=$(( cur + 1 ))
        done
      fi
      ;;
  esac
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_get_wan - set WAN_GW and WAN_IF
# Excludes VPN interfaces so we always get the physical WAN route.

dvpn_get_wan()
{
  WAN_GW=$(ip route show default table main 2>/dev/null | \
           awk '/^default/ && ($0 !~ /wgc/ && $0 !~ /tun/) {print $3; exit}')
  WAN_IF=$(ip route show default table main 2>/dev/null | \
           awk '/^default/ && ($0 !~ /wgc/ && $0 !~ /tun/) {print $5; exit}')
  # Fallback to any default route if pure-WAN search fails
  if [ -z "$WAN_GW" ]; then
    WAN_GW=$(ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}')
    WAN_IF=$(ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}')
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_resolve_host - resolve a hostname to an IPv4 address.

dvpn_resolve_host()
{
  local h="$1" ip

  if ! echo "$h" | grep -qE '[a-zA-Z]'; then
    echo "$h"; return
  fi

  ip=$(nslookup "$h" 2>/dev/null | awk '
    /^Server:/  { match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); s=substr($0,RSTART,RLENGTH) }
    /^Address/  { match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); v=substr($0,RSTART,RLENGTH)
                  if (v != "" && v != s) { print v; exit } }
  ')

  # Fallback: ping resolves the hostname and prints it in parens on the first line
  if [ -z "$ip" ]; then
    ip=$(ping -c1 -w2 "$h" 2>/dev/null | sed -n '1s/.*(\([0-9.]*\)).*/\1/p')
  fi

  [ -n "$ip" ] && echo "$ip" || echo "$h"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_get_endpoint - return current endpoint IP for a tunnel from NVRAM.
# WireGuard: wgcN_ep_addr (IP:port or hostname:port - strip port, resolve if hostname)
# OpenVPN:   vpn_clientN_addr (hostname or IP - resolve if hostname)

dvpn_get_endpoint()
{
  local type="$1" slot="$2"
  local raw ep

  if [ "$type" = "wg" ]; then
    raw=$(nvram get "wgc${slot}_ep_addr" 2>/dev/null)
    ep=$(dvpn_resolve_host "$(echo "$raw" | cut -d: -f1)")
  else
    raw=$(nvram get "vpn_client${slot}_addr" 2>/dev/null)
    ep=$(dvpn_resolve_host "$raw")
  fi
  echo "$ep"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_get_if_addr - return IPv4 address of an interface (no prefix length)

dvpn_get_if_addr()
{
  ip -4 addr show dev "$1" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_get_if_cidr - return IPv4 address/prefix of an interface

dvpn_get_if_cidr()
{
  ip -4 addr show dev "$1" 2>/dev/null | awk '/inet / {print $2}' | head -1
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_tunnel_is_up - test whether a configured tunnel is fully operational.
# Used by dvpn_check_and_apply each time through the timer loop.
# Returns 0 (true = UP) or 1 (false = DOWN).

dvpn_tunnel_is_up()
{
  local type="$1" slot="$2" iface="$3"

  if [ "$type" = "wg" ]; then
    [ "$(dvpn_wg_slot_status "$slot")" = "UP" ] && return 0 || return 1
  else
    [ "$(dvpn_ovpn_slot_status "$slot")" = "UP" ] && return 0 || return 1
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# VPN Director state management
# Save, suspend, and restore ip rules for double-hop client IPs so that VPN Director and our double-hop rules don't conflict.

dvpn_save_vd_rules()
{
  # Create file if missing
  [ -f "$DVPN_SAVED_RULES" ] || touch "$DVPN_SAVED_RULES"

  local entry fmt start end s_int e_int cur ip line

  for entry in $DVPN_HOP_IPS; do
    fmt=$(dvpn_ip_format "$entry")
    case "$fmt" in
      single|cidr)
        while IFS= read -r line; do
          [ -z "$line" ] && continue
          # Only append if not already in the file
          grep -qF "$line" "$DVPN_SAVED_RULES" 2>/dev/null || \
            echo "$line" >> "$DVPN_SAVED_RULES"
        done <<EOF
$(ip rule show 2>/dev/null | grep "from $entry")
EOF
        ;;
      range)
        start=$(echo "$entry" | cut -d- -f1)
        end=$(echo "$entry" | cut -d- -f2)
        s_int=$(dvpn_ip_to_int "$start")
        e_int=$(dvpn_ip_to_int "$end")
        cur=$s_int
        while [ "$cur" -le "$e_int" ]; do
          ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
          while IFS= read -r line; do
            [ -z "$line" ] && continue
            grep -qF "$line" "$DVPN_SAVED_RULES" 2>/dev/null || \
              echo "$line" >> "$DVPN_SAVED_RULES"
          done <<EOF
$(ip rule show 2>/dev/null | grep "from $ip")
EOF
          cur=$(( cur + 1 ))
        done
        ;;
    esac
  done

  local saved
  saved=$(wc -l < "$DVPN_SAVED_RULES" 2>/dev/null || echo 0)
  [ "$saved" -gt 0 ] && \
    dvpn_log "INFO: Saved rules file now contains $saved VPN/DNS Director rule(s)"
}

dvpn_suspend_vd_rules()
{
  local entry fmt start end s_int e_int cur ip prio

  for entry in $DVPN_HOP_IPS; do
    fmt=$(dvpn_ip_format "$entry")
    case "$fmt" in
      single|cidr)
        while ip rule show 2>/dev/null | grep -q "from $entry"; do
          prio=$(ip rule show 2>/dev/null | grep "from $entry" | \
                 head -1 | awk -F: '{print $1}' | tr -d ' ')
          [ -z "$prio" ] && break
          ip rule del prio "$prio" 2>/dev/null && \
            dvpn_log "INFO: Suspended VPN Director rule prio $prio for $entry"
        done
        ;;
      range)
        start=$(echo "$entry" | cut -d- -f1)
        end=$(echo "$entry" | cut -d- -f2)
        s_int=$(dvpn_ip_to_int "$start")
        e_int=$(dvpn_ip_to_int "$end")
        cur=$s_int
        while [ "$cur" -le "$e_int" ]; do
          ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
          while ip rule show 2>/dev/null | grep -q "from $ip"; do
            prio=$(ip rule show 2>/dev/null | grep "from $ip" | \
                   head -1 | awk -F: '{print $1}' | tr -d ' ')
            [ -z "$prio" ] && break
            ip rule del prio "$prio" 2>/dev/null
          done
          cur=$(( cur + 1 ))
        done
        ;;
    esac
  done
}

dvpn_restore_vd_rules()
{
  [ ! -s "$DVPN_SAVED_RULES" ] && \
    { dvpn_log "INFO: No saved VPN Director rules to restore"; return; }

  local rule prio src table
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    prio=$(echo "$rule" | awk -F: '{print $1}' | tr -d ' ')
    src=$(echo "$rule" | awk '{print $3}')
    table=$(echo "$rule" | awk '{print $NF}')
    if [ -n "$prio" ] && [ -n "$src" ] && [ -n "$table" ]; then
      ip rule add from "$src" table "$table" prio "$prio" 2>/dev/null && \
        dvpn_log "INFO: Restored VPN Director rule: prio $prio from $src -> table $table"
    fi
  done < "$DVPN_SAVED_RULES"

  rm -f "$DVPN_SAVED_RULES"
  dvpn_log "INFO: VPN Director rules restored"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_build_table - flush and rebuild a routing table for a tunnel interface

dvpn_build_table()
{
  local table="$1" iface="$2" if_cidr="$3" mark="$4"

  ip route flush table "$table" 2>/dev/null

  [ -n "$if_cidr" ] && \
    ip route add "$if_cidr" dev "$iface" table "$table" 2>/dev/null

  ip route add default dev "$iface" table "$table"
  dvpn_log "INFO: Table $table - default -> $iface"

  # Remove the per-tunnel fwmark rule before re-adding
  ip rule del fwmark "$mark" table "$table" 2>/dev/null
  ip rule add fwmark "$mark" table "$table" prio $((9000 + table))
  dvpn_log "INFO: ip rule - fwmark $mark -> table $table (prio $((9000 + table)))"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_tunnel1_up - pin T1 endpoint to WAN, build T1 routing table

dvpn_tunnel1_up()
{
  dvpn_log "INFO: ---> T1 UP start (${DVPN_TUNNEL1_TYPE} slot ${DVPN_TUNNEL1_SLOT} / ${DVPN_TUNNEL1_IF})"

  dvpn_get_wan
  if [ -z "$WAN_GW" ] || [ -z "$WAN_IF" ]; then
    dvpn_log "ERROR: T1 UP - cannot determine WAN gateway -- aborting"
    return 1
  fi

  local ep
  ep=$(dvpn_get_endpoint "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT")
  if [ -z "$ep" ]; then
    dvpn_log "ERROR: T1 UP - cannot determine endpoint -- aborting"
    return 1
  fi

  # Pin T1 endpoint to physical WAN (prevents routing loop through VPN)
  ip route del "${ep}/32" 2>/dev/null
  ip route add "${ep}/32" via "$WAN_GW" dev "$WAN_IF"
  dvpn_log "INFO: T1 UP - pinned $ep -> WAN ($WAN_IF via $WAN_GW)"

  local if_cidr
  if_cidr=$(dvpn_get_if_cidr "$DVPN_TUNNEL1_IF")
  if [ -z "$if_cidr" ]; then
    dvpn_log "ERROR: T1 UP - cannot get address for $DVPN_TUNNEL1_IF -- aborting"
    return 1
  fi

  dvpn_build_table "$DVPN_TUNNEL1_TABLE" "$DVPN_TUNNEL1_IF" "$if_cidr" "$DVPN_TUNNEL1_MARK"
  ip route flush cache
  dvpn_log "INFO: ---> T1 UP complete (ep=$ep iface=$DVPN_TUNNEL1_IF cidr=$if_cidr)"
  return 0
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_add_hop_rules - add direct from-IP ip rules for all hop client entries at DVPN_HOP_PRIO, routing them to DVPN_TUNNEL2_TABLE.
# Called from dvpn_tunnel2_up after the table and fwmark rules are set.

dvpn_add_hop_rules()
{
  local entry fmt start end s_int e_int cur ip

  for entry in $DVPN_HOP_IPS; do
    fmt=$(dvpn_ip_format "$entry")
    case "$fmt" in
      single|cidr)
        # Remove any existing prio-99 rule for this IP (any table) before adding
        while ip rule show 2>/dev/null | grep -q "^${DVPN_HOP_PRIO}:.*from ${entry}"; do
          ip rule del from "$entry" prio "$DVPN_HOP_PRIO" 2>/dev/null || break
        done
        ip rule add from "$entry" lookup "$DVPN_TUNNEL2_TABLE" prio "$DVPN_HOP_PRIO"
        dvpn_log "INFO: Added hop rule - from $entry -> table $DVPN_TUNNEL2_TABLE (prio $DVPN_HOP_PRIO)"
        ;;
      range)
        start=$(echo "$entry" | cut -d- -f1)
        end=$(echo "$entry" | cut -d- -f2)
        s_int=$(dvpn_ip_to_int "$start")
        e_int=$(dvpn_ip_to_int "$end")
        cur=$s_int
        while [ "$cur" -le "$e_int" ]; do
          ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
          while ip rule show 2>/dev/null | grep -q "^${DVPN_HOP_PRIO}:.*from ${ip}"; do
            ip rule del from "$ip" prio "$DVPN_HOP_PRIO" 2>/dev/null || break
          done
          ip rule add from "$ip" lookup "$DVPN_TUNNEL2_TABLE" prio "$DVPN_HOP_PRIO"
          cur=$(( cur + 1 ))
        done
        dvpn_log "INFO: Added hop rules for range $entry -> table $DVPN_TUNNEL2_TABLE (prio $DVPN_HOP_PRIO)"
        ;;
    esac
  done

  # Write the installed IPs file so dvpn_tunnel2_down can clean up even if DVPN_HOP_IPS changes before teardown.
  echo "$DVPN_HOP_IPS" > "$DVPN_INSTALLED_IPS_FILE"
  dvpn_log "INFO: Installed IPs recorded: $DVPN_HOP_IPS"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_del_hop_rules - remove direct from-IP ip rules added by dvpn_add_hop_rules.
# Called from dvpn_tunnel2_down.

dvpn_del_hop_rules()
{
  # Use installed IPs if available, fall back to current config
  local installed_ips
  if [ -f "$DVPN_INSTALLED_IPS_FILE" ]; then
    installed_ips=$(cat "$DVPN_INSTALLED_IPS_FILE")
    dvpn_log "INFO: Removing hop rules for installed IPs: $installed_ips"
  else
    installed_ips="$DVPN_HOP_IPS"
    dvpn_log "INFO: No installed IPs file found, using current config: $installed_ips"
  fi

  local entry fmt start end s_int e_int cur ip

  for entry in $installed_ips; do
    fmt=$(dvpn_ip_format "$entry")
    case "$fmt" in
      single|cidr)
        # Remove ALL prio-99 rules for this IP regardless of which table they point to
        while ip rule show 2>/dev/null | grep -q "^${DVPN_HOP_PRIO}:.*from ${entry}"; do
          ip rule del from "$entry" prio "$DVPN_HOP_PRIO" 2>/dev/null || break
        done
        dvpn_log "INFO: Removed hop rule(s) - from $entry (prio $DVPN_HOP_PRIO)"
        ;;
      range)
        start=$(echo "$entry" | cut -d- -f1)
        end=$(echo "$entry" | cut -d- -f2)
        s_int=$(dvpn_ip_to_int "$start")
        e_int=$(dvpn_ip_to_int "$end")
        cur=$s_int
        while [ "$cur" -le "$e_int" ]; do
          ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
          while ip rule show 2>/dev/null | grep -q "^${DVPN_HOP_PRIO}:.*from ${ip}"; do
            ip rule del from "$ip" prio "$DVPN_HOP_PRIO" 2>/dev/null || break
          done
          cur=$(( cur + 1 ))
        done
        dvpn_log "INFO: Removed hop rules for range $entry (prio $DVPN_HOP_PRIO)"
        ;;
    esac
  done

  rm -f "$DVPN_INSTALLED_IPS_FILE"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_tunnel2_up - route T2 endpoint through T1, build T2 table, apply all hop rules.

dvpn_tunnel2_up()
{
  dvpn_log "INFO: ---> T2 UP start (${DVPN_TUNNEL2_TYPE} slot ${DVPN_TUNNEL2_SLOT} / ${DVPN_TUNNEL2_IF})"

  if ! ip link show "$DVPN_TUNNEL1_IF" > /dev/null 2>&1; then
    dvpn_log "ERROR: T2 UP - $DVPN_TUNNEL1_IF not up -- cannot proceed"
    return 1
  fi
  if ! ip route show table "$DVPN_TUNNEL1_TABLE" 2>/dev/null | grep -q "^default"; then
    dvpn_log "WARNING: T2 UP - table $DVPN_TUNNEL1_TABLE has no default route -- T1 setup incomplete"
    return 1
  fi

  local t1_addr ep if_cidr
  t1_addr=$(dvpn_get_if_addr "$DVPN_TUNNEL1_IF")

  ep=$(dvpn_get_endpoint "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT")
  if [ -z "$ep" ]; then
    dvpn_log "ERROR: T2 UP - cannot determine endpoint -- aborting"
    return 1
  fi

  ip route del "${ep}/32" 2>/dev/null
  if [ -n "$t1_addr" ]; then
    ip route add "${ep}/32" dev "$DVPN_TUNNEL1_IF" src "$t1_addr" table main
  else
    ip route add "${ep}/32" dev "$DVPN_TUNNEL1_IF" table main
  fi
  dvpn_log "INFO: T2 UP - pinned $ep -> $DVPN_TUNNEL1_IF (rides inside T1)"

  if_cidr=$(dvpn_get_if_cidr "$DVPN_TUNNEL2_IF")
  if [ -z "$if_cidr" ]; then
    dvpn_log "ERROR: T2 UP - cannot get address for $DVPN_TUNNEL2_IF -- aborting"
    return 1
  fi

  dvpn_build_table "$DVPN_TUNNEL2_TABLE" "$DVPN_TUNNEL2_IF" "$if_cidr" "$DVPN_TUNNEL2_MARK"

  # Save and suspend VPN/DNS Director rules for hop IPs
  dvpn_save_vd_rules
  dvpn_suspend_vd_rules

  # Direct from-IP rules at DVPN_HOP_PRIO
  # dvpn_add_hop_rules handles removal of stale prio-99 rules internally
  dvpn_add_hop_rules

  # Remove ALL existing fwmark rules for DVPN_HOP_MARK before adding the new one.
  while ip rule show 2>/dev/null | grep -q "fwmark ${DVPN_HOP_MARK}"; do
    local stale_table
    stale_table=$(ip rule show 2>/dev/null | grep "fwmark ${DVPN_HOP_MARK}" | \
                  head -1 | awk '{print $NF}')
    [ -z "$stale_table" ] && break
    ip rule del fwmark "$DVPN_HOP_MARK" table "$stale_table" prio 9000 2>/dev/null || \
    ip rule del fwmark "$DVPN_HOP_MARK" 2>/dev/null || break
  done
  ip rule add fwmark "$DVPN_HOP_MARK" table "$DVPN_TUNNEL2_TABLE" prio 9000
  dvpn_log "INFO: T2 UP - fwmark $DVPN_HOP_MARK -> table $DVPN_TUNNEL2_TABLE (prio 9000)"

  # Mangle marks and MSS clamping
  # Read installed IPs from file if available (handles case where DVPN_HOP_IPS changed since last teardown - clean up old entries first)
  local prev_ips=""
  [ -f "$DVPN_INSTALLED_IPS_FILE" ] && prev_ips=$(cat "$DVPN_INSTALLED_IPS_FILE")
  if [ -n "$prev_ips" ] && [ "$prev_ips" != "$DVPN_HOP_IPS" ]; then
    dvpn_log "INFO: T2 UP - cleaning up mangle rules for previous IPs: $prev_ips"
    local prev_entry mss=1300
    for prev_entry in $prev_ips; do
      dvpn_mangle_rule del "$prev_entry" "$DVPN_HOP_MARK" 2>/dev/null
      dvpn_mss_rule del "$prev_entry" "$mss" 2>/dev/null
    done
  fi

  local entry mss=1300
  for entry in $DVPN_HOP_IPS; do
    dvpn_mangle_rule del "$entry" "$DVPN_HOP_MARK" 2>/dev/null
    dvpn_mangle_rule add "$entry" "$DVPN_HOP_MARK"
    dvpn_mss_rule del "$entry" "$mss" 2>/dev/null
    dvpn_mss_rule add "$entry" "$mss"
    dvpn_log "INFO: T2 UP - mark + MSS applied for $entry"
  done

  ip route flush cache
  dvpn_log "INFO: ---> T2 UP complete (ep=$ep iface=$DVPN_TUNNEL2_IF cidr=$if_cidr)"
  return 0
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_tunnel1_down - remove T1 endpoint host route and routing table

dvpn_tunnel1_down()
{
  dvpn_log "INFO: ---> T1 DOWN start"

  local ep
  ep=$(dvpn_get_endpoint "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT")
  if [ -z "$ep" ]; then
    # Try NVRAM directly as fallback
    ep=$(nvram get "wgc${DVPN_TUNNEL1_SLOT}_ep_addr" 2>/dev/null | cut -d: -f1)
  fi
  if [ -n "$ep" ]; then
    ip route del "${ep}/32" 2>/dev/null
    dvpn_log "INFO: T1 DOWN - removed host route for $ep"
  fi

  ip rule del fwmark "$DVPN_TUNNEL1_MARK" table "$DVPN_TUNNEL1_TABLE" 2>/dev/null
  ip route flush table "$DVPN_TUNNEL1_TABLE" 2>/dev/null
  ip route flush cache
  dvpn_log "INFO: ---> T1 DOWN complete"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_tunnel2_down - remove all T2 rules including direct hop rules.

dvpn_tunnel2_down()
{
  dvpn_log "INFO: ---> T2 DOWN start"

  # Use installed IPs for mangle and MSS cleanup
  local installed_ips
  if [ -f "$DVPN_INSTALLED_IPS_FILE" ]; then
    installed_ips=$(cat "$DVPN_INSTALLED_IPS_FILE")
    dvpn_log "INFO: T2 DOWN - cleaning up rules for installed IPs: $installed_ips"
  else
    installed_ips="$DVPN_HOP_IPS"
    dvpn_log "INFO: T2 DOWN - no installed IPs file, using current config: $installed_ips"
  fi

  local entry mss=1300
  for entry in $installed_ips; do
    dvpn_mangle_rule del "$entry" "$DVPN_HOP_MARK"
    dvpn_mss_rule del "$entry" "$mss"
  done

  # Remove direct from-IP hop rules (uses installed IPs internally)
  dvpn_del_hop_rules

  # Remove ALL fwmark rules for DVPN_HOP_MARK (any table)
  while ip rule show 2>/dev/null | grep -q "fwmark ${DVPN_HOP_MARK}"; do
    local stale_table
    stale_table=$(ip rule show 2>/dev/null | grep "fwmark ${DVPN_HOP_MARK}" | \
                  head -1 | awk '{print $NF}')
    [ -z "$stale_table" ] && break
    ip rule del fwmark "$DVPN_HOP_MARK" table "$stale_table" 2>/dev/null || \
    ip rule del fwmark "$DVPN_HOP_MARK" 2>/dev/null || break
  done

  local ep
  ep=$(dvpn_get_endpoint "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT")
  [ -z "$ep" ] && ep=$(nvram get "wgc${DVPN_TUNNEL2_SLOT}_ep_addr" 2>/dev/null | cut -d: -f1)
  [ -n "$ep" ] && ip route del "${ep}/32" 2>/dev/null

  ip rule del fwmark "$DVPN_TUNNEL2_MARK" table "$DVPN_TUNNEL2_TABLE" 2>/dev/null
  ip route flush table "$DVPN_TUNNEL2_TABLE" 2>/dev/null

  dvpn_restore_vd_rules
  ip route flush cache
  dvpn_log "INFO: ---> T2 DOWN complete"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_nuke_orphans — one-time cleanup for any orphaned rules left by previous versions of the code.

dvpn_nuke_orphans()
{
  dvpn_log "INFO: Running orphan rule cleanup"

  # Remove all prio-99 ip rules (our hop rules span 99)
  while ip rule show 2>/dev/null | grep -q "^99:"; do
    local entry
    entry=$(ip rule show 2>/dev/null | grep "^99:" | head -1 | awk '{print $3}')
    [ -z "$entry" ] && break
    ip rule del from "$entry" prio 99 2>/dev/null || break
    dvpn_log "INFO: Removed orphan prio-99 rule for $entry"
  done

  # Remove all fwmark 0x1cc rules (any priority, any table)
  local hop_mark_dec
  hop_mark_dec=$(printf "%d" "$DVPN_HOP_MARK" 2>/dev/null)
  while ip rule show 2>/dev/null | grep -qiE "fwmark.*(${DVPN_HOP_MARK}|${hop_mark_dec})"; do
    local stale_table
    stale_table=$(ip rule show 2>/dev/null | grep -i "${DVPN_HOP_MARK}" | head -1 | awk '{print $NF}')
    [ -z "$stale_table" ] && break
    ip rule del fwmark "$DVPN_HOP_MARK" table "$stale_table" 2>/dev/null || \
    ip rule del fwmark "$DVPN_HOP_MARK" 2>/dev/null || break
    dvpn_log "INFO: Removed orphan fwmark rule -> table $stale_table"
  done

  # Remove all mangle PREROUTING mark rules setting 0x1cc
  while iptables -t mangle -L PREROUTING -n 2>/dev/null | \
        grep -qiE "MARK set ${DVPN_HOP_MARK}|MARK set ${hop_mark_dec}"; do
    iptables -t mangle -D PREROUTING \
      -j MARK --set-mark "$DVPN_HOP_MARK" 2>/dev/null || break
    dvpn_log "INFO: Removed orphan mangle PREROUTING mark rule"
  done

  dvpn_log "INFO: Orphan cleanup complete"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_read_state - load state file variables into local scope
# Sets: ST1_UP, ST1_EP, ST2_UP, ST2_EP

dvpn_read_state()
{
  ST1_UP=0; ST1_EP=""
  ST2_UP=0; ST2_EP=""
  [ -f "$DVPN_STATE_FILE" ] && . "$DVPN_STATE_FILE"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_write_state - persist current state to state file

dvpn_write_state()
{
  {
    echo "ST1_UP=$1"
    echo "ST1_EP=\"$2\""
    echo "ST2_UP=$3"
    echo "ST2_EP=\"$4\""
  } > "$DVPN_STATE_FILE"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_routing_intact - verify the routing infrastructure is actually in place.
# Returns 0 (intact) or 1 (missing/broken).

dvpn_routing_intact()
{
  # Check 1: T1 table has a default route via the correct interface
  if ! ip route show table "$DVPN_TUNNEL1_TABLE" 2>/dev/null | \
       grep -q "^default.*$DVPN_TUNNEL1_IF"; then
    dvpn_log "WARNING: Integrity - T1 table $DVPN_TUNNEL1_TABLE missing default route via $DVPN_TUNNEL1_IF"
    return 1
  fi

  # Check 2: T2 table has a default route via the correct interface
  if ! ip route show table "$DVPN_TUNNEL2_TABLE" 2>/dev/null | \
       grep -q "^default.*$DVPN_TUNNEL2_IF"; then
    dvpn_log "WARNING: Integrity - T2 table $DVPN_TUNNEL2_TABLE missing default route via $DVPN_TUNNEL2_IF"
    return 1
  fi

  # Check 3: direct from-IP hop rule exists at DVPN_HOP_PRIO for first hop entry
  local first_entry fmt
  first_entry=$(echo "$DVPN_HOP_IPS" | awk '{print $1}')
  fmt=$(dvpn_ip_format "$first_entry")

  case "$fmt" in
    single|cidr)
      if ! ip rule show 2>/dev/null | \
           grep -q "^${DVPN_HOP_PRIO}:.*from ${first_entry}.*lookup ${DVPN_TUNNEL2_TABLE}"; then
        dvpn_log "WARNING: Integrity - direct hop rule missing for $first_entry -> table $DVPN_TUNNEL2_TABLE (prio $DVPN_HOP_PRIO)"
        return 1
      fi
      ;;
    range)
      # For ranges, check that a priority-99 rule pointing to T2 table exists
      local start
      start=$(echo "$first_entry" | cut -d- -f1)
      if ! ip rule show 2>/dev/null | \
           grep -q "^${DVPN_HOP_PRIO}:.*from ${start}.*lookup ${DVPN_TUNNEL2_TABLE}"; then
        dvpn_log "WARNING: Integrity - direct hop rule missing for range start $start -> table $DVPN_TUNNEL2_TABLE"
        return 1
      fi
      ;;
  esac

  # Check 4: iptables mangle PREROUTING mark rule for first hop entry
  case "$fmt" in
    single|cidr)
      if ! iptables -t mangle -L PREROUTING -n 2>/dev/null | \
           grep -q "$first_entry"; then
        dvpn_log "WARNING: Integrity - mangle PREROUTING mark rule missing for $first_entry"
        return 1
      fi
      ;;
    range)
      local hop_mark_dec
      hop_mark_dec=$(printf "%d" "$DVPN_HOP_MARK" 2>/dev/null)
      if ! iptables -t mangle -L PREROUTING -n 2>/dev/null | \
           grep -iE "MARK.*(${DVPN_HOP_MARK}|${hop_mark_dec})" | grep -qi "mark"; then
        dvpn_log "WARNING: Integrity - mangle PREROUTING mark rule missing for range $first_entry"
        return 1
      fi
      ;;
  esac

  # Check 5: no VPN Director rule exists for any hop IP at a priority LOWER than DVPN_HOP_PRIO (which would override the rules).
  # If found, return 1 to trigger a rebuild that will re-suspend them.
  local entry vd_prio vd_rule
  for entry in $DVPN_HOP_IPS; do
    fmt=$(dvpn_ip_format "$entry")
    case "$fmt" in
      single|cidr)
        # Look for any rule "from <entry>" whose priority number < DVPN_HOP_PRIO
        while IFS= read -r vd_rule; do
          [ -z "$vd_rule" ] && continue
          vd_prio=$(echo "$vd_rule" | awk -F: '{print $1}' | tr -d ' ')
          # Skip if it's our own rule pointing to T2 table
          echo "$vd_rule" | grep -q "lookup $DVPN_TUNNEL2_TABLE" && continue
          if [ -n "$vd_prio" ] && [ "$vd_prio" -lt "$DVPN_HOP_PRIO" ] 2>/dev/null; then
            dvpn_log "WARNING: Integrity - conflicting VPN Director rule at prio $vd_prio for $entry overrides hop routing -- rebuilding"
            return 1
          fi
        done <<EOF
$(ip rule show 2>/dev/null | grep "from $entry")
EOF
        ;;
      range)
        # For ranges, check the start IP as representative
        local start
        start=$(echo "$entry" | cut -d- -f1)
        while IFS= read -r vd_rule; do
          [ -z "$vd_rule" ] && continue
          vd_prio=$(echo "$vd_rule" | awk -F: '{print $1}' | tr -d ' ')
          echo "$vd_rule" | grep -q "lookup $DVPN_TUNNEL2_TABLE" && continue
          if [ -n "$vd_prio" ] && [ "$vd_prio" -lt "$DVPN_HOP_PRIO" ] 2>/dev/null; then
            dvpn_log "WARNING: Integrity - conflicting VPN Director rule at prio $vd_prio for range $entry -- rebuilding"
            return 1
          fi
        done <<EOF
$(ip rule show 2>/dev/null | grep "from $start")
EOF
        ;;
    esac
  done

  return 0
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_check_and_apply - state machine called each monitoring loop iteration.
#
# Logic order:
#   1. If either tunnel is down, handle teardown/rebuild
#   2. If both tunnels are up and endpoints changed, rebuild.
#   3. If both tunnels are up, endpoints unchanged, but routing infrastructure is missing, force a full rebuild.

dvpn_check_and_apply()
{
  [ "$DVPN_ENABLED" != "1" ] && return
  [ -z "$DVPN_HOP_IPS" ]    && return

  dvpn_read_state

  local cur1_up=0 cur2_up=0 cur1_ep cur2_ep

  dvpn_tunnel_is_up "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT" && cur1_up=1
  dvpn_tunnel_is_up "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT" && cur2_up=1
  cur1_ep=$(dvpn_get_endpoint "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT")
  cur2_ep=$(dvpn_get_endpoint "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT")

  # T1 dropped
  if [ "$ST1_UP" = "1" ] && [ "$cur1_up" = "0" ]; then
    dvpn_log "WARNING: State - T1 went DOWN -- tearing down T2 then T1 routing"
    [ "$ST2_UP" = "1" ] && dvpn_tunnel2_down
    dvpn_tunnel1_down
    dvpn_write_state 0 "" 0 ""
    return
  fi

  # T1 came up
  if [ "$ST1_UP" = "0" ] && [ "$cur1_up" = "1" ]; then
    dvpn_log "INFO: State - T1 came UP (ep=$cur1_ep)"
    dvpn_tunnel1_up
    if [ "$cur2_up" = "1" ]; then
      dvpn_log "INFO: State - T2 also UP -- applying T2 routing"
      dvpn_tunnel2_up
      dvpn_write_state 1 "$cur1_ep" 1 "$cur2_ep"
    else
      dvpn_write_state 1 "$cur1_ep" 0 ""
    fi
    return
  fi

  # T1 server changed
  if [ "$ST1_UP" = "1" ] && [ "$cur1_up" = "1" ] && \
     [ -n "$cur1_ep" ] && [ -n "$ST1_EP" ] && [ "$cur1_ep" != "$ST1_EP" ]; then
    dvpn_log "WARNING: State - T1 server changed ($ST1_EP -> $cur1_ep) -- rebuilding"
    [ "$ST2_UP" = "1" ] && dvpn_tunnel2_down
    dvpn_tunnel1_down
    dvpn_tunnel1_up
    if [ "$cur2_up" = "1" ]; then
      dvpn_tunnel2_up
      dvpn_write_state 1 "$cur1_ep" 1 "$cur2_ep"
    else
      dvpn_write_state 1 "$cur1_ep" 0 ""
    fi
    return
  fi

  # T2 dropped
  if [ "$ST2_UP" = "1" ] && [ "$cur2_up" = "0" ]; then
    dvpn_log "WARNING: State - T2 went DOWN -- tearing down T2 routing"
    dvpn_tunnel2_down
    dvpn_write_state "$cur1_up" "$cur1_ep" 0 ""
    return
  fi

  # T2 came up (T1 must be up first)
  if [ "$ST2_UP" = "0" ] && [ "$cur2_up" = "1" ] && [ "$cur1_up" = "1" ]; then
    dvpn_log "INFO: State - T2 came UP (ep=$cur2_ep)"
    dvpn_tunnel2_up
    dvpn_write_state 1 "$cur1_ep" 1 "$cur2_ep"
    return
  fi

  # T2 server changed
  if [ "$ST2_UP" = "1" ] && [ "$cur2_up" = "1" ] && \
     [ -n "$cur2_ep" ] && [ -n "$ST2_EP" ] && [ "$cur2_ep" != "$ST2_EP" ]; then
    dvpn_log "INFO: State - T2 server changed ($ST2_EP -> $cur2_ep) -- rebuilding T2"
    dvpn_tunnel2_down
    dvpn_tunnel2_up
    dvpn_write_state "$cur1_up" "$cur1_ep" 1 "$cur2_ep"
    return
  fi

  # Both tunnels UP, endpoints unchanged - verify routing is intact
  # State and endpoints look identical but routing tables may have been wiped.
  if [ "$cur1_up" = "1" ] && [ "$cur2_up" = "1" ]; then
    if ! dvpn_routing_intact; then
      dvpn_log "WARNING: State - tunnels UP but routing infrastructure missing -- forcing full rebuild"
      dvpn_tunnel2_down 2>/dev/null
      dvpn_tunnel1_down 2>/dev/null
      dvpn_tunnel1_up
      dvpn_tunnel2_up
      dvpn_write_state 1 "$cur1_ep" 1 "$cur2_ep"
      return
    fi
  fi

  # No change - refresh EPs in state file
  dvpn_write_state "$cur1_up" "$cur1_ep" "$cur2_up" "$cur2_ep"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_on_tunnel_restart - called immediately after restartvpn/restartwg
# Proactively tears down routing for the affected tunnel so stale routes are cleaned before dvpn_check_and_apply rebuilds on the next iteration.

dvpn_on_tunnel_restart()
{
  local type="$1" slot="$2"
  [ "$DVPN_ENABLED" != "1" ] && return

  if [ "$type" = "$DVPN_TUNNEL1_TYPE" ] && [ "$slot" = "$DVPN_TUNNEL1_SLOT" ]; then
    dvpn_log "INFO: Tunnel restart - T1 (${type} slot ${slot}) -- clearing routing stack"
    dvpn_tunnel2_down 2>/dev/null
    dvpn_tunnel1_down 2>/dev/null
    rm -f "$DVPN_STATE_FILE"

  elif [ "$type" = "$DVPN_TUNNEL2_TYPE" ] && [ "$slot" = "$DVPN_TUNNEL2_SLOT" ]; then
    dvpn_log "INFO: Tunnel restart - T2 (${type} slot ${slot}) -- clearing T2 routing"
    dvpn_tunnel2_down 2>/dev/null
    # Update state: T2 is now down, T1 state preserved
    dvpn_read_state
    dvpn_write_state "$ST1_UP" "$ST1_EP" 0 ""
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_display_status - render the Double-Hop section in the main VPNMON-R3 UI.
# Renders nothing when DVPN_ENABLED=0.

dvpn_display_status()
{
  [ "$DVPN_ENABLED" != "1" ] && return

  dvpn_read_state

  local wgbin
  wgbin=$(dvpn_find_wg)

  # Tunnel 1 display
  local t1_color t1_label t1_detail t1_ep_disp t1_type_disp
  [ "$DVPN_TUNNEL1_TYPE" = "wg" ] && t1_type_disp="WGC" || t1_type_disp="VPN"

  if [ "$ST1_UP" = "1" ]; then
    t1_color="$CGreen"
    t1_label="Active"
    t1_ep_disp="${ST1_EP:-unknown}"

    if [ "$DVPN_TUNNEL1_TYPE" = "wg" ] && [ -n "$wgbin" ]; then
      local hs now age
      hs=$(dvpn_wg_latest_hs "$DVPN_TUNNEL1_IF")
      if [ -n "$hs" ] && [ "$hs" != "0" ]; then
        now=$(date +%s)
        age=$(( now - hs ))
        t1_detail="HS: ${age}s ago"
      else
        t1_detail="HS: Pending"
      fi
    elif [ "$DVPN_TUNNEL1_TYPE" = "wg" ] && [ -z "$wgbin" ]; then
      t1_detail="HS: n/a (no wg)"
    else
      t1_detail="OVPN state: 2"
    fi
  else
    t1_color="$CRed"
    t1_label="Down  "
    t1_detail="Waiting..."
    t1_ep_disp="---"
  fi

  # Tunnel 2 display
  local t2_color t2_label t2_detail t2_ep_disp t2_type_disp
  [ "$DVPN_TUNNEL2_TYPE" = "wg" ] && t2_type_disp="WGC" || t2_type_disp="VPN"

  if [ "$ST2_UP" = "1" ]; then
    t2_color="$CGreen"
    t2_label="Active"
    t2_ep_disp="${ST2_EP:-unknown}"

    if [ "$DVPN_TUNNEL2_TYPE" = "wg" ] && [ -n "$wgbin" ]; then
      local hs now age
      hs=$(dvpn_wg_latest_hs "$DVPN_TUNNEL2_IF")
      if [ -n "$hs" ] && [ "$hs" != "0" ]; then
        now=$(date +%s)
        age=$(( now - hs ))
        t2_detail="HS: ${age}s ago"
      else
        t2_detail="HS: Pending"
      fi
    elif [ "$DVPN_TUNNEL2_TYPE" = "wg" ] && [ -z "$wgbin" ]; then
      t2_detail="HS: n/a (no wg)"
    else
      t2_detail="OVPN state: 2"
    fi
  else
    t2_color="$CRed"
    t2_label="Down  "
    t2_detail="Waiting..."
    t2_ep_disp="---"
  fi

  # Overall hop status
  local hop_color hop_status
  if [ "$ST1_UP" = "1" ] && [ "$ST2_UP" = "1" ]; then
    hop_color="$CGreen"; hop_status="| ROUTING ACTIVE"
  elif [ "$ST1_UP" = "1" ] || [ "$ST2_UP" = "1" ]; then
    hop_color="$CYellow"; hop_status="| PARTIAL       "
  else
    hop_color="$CRed"; hop_status="| INACTIVE      "
  fi

  # Truncate hop IPs display if too long for the line
  local hop_ips_disp="$DVPN_HOP_IPS"
  [ ${#hop_ips_disp} -gt 41 ] && hop_ips_disp="$(echo "$DVPN_HOP_IPS" | cut -c1-38)..."

  # Insert bogus IP if screenshotmode is on #
  if [ "$screenshotmode" = "1" ]; then
     t1_ep_disp="$(printf '%15s' "12.34.56.78")"
     t2_ep_disp="$(printf '%15s' "12.34.56.78")"
  fi

  echo -e "${InvDkGray}${CWhite} Double-Hop VPN ${hop_color}${hop_status}${InvDkGray}                                                                                                 ${CClear}"
  echo ""
  echo -e "  Slot | Tunnel Layer | IFace  | Status       | Endpoint IP     | Connection State    | Hop Client(s) / Mark -> Table"
  echo -e "-------|--------------|--------|--------------|-----------------|---------------------|------------------------------------------"
  printf "${InvGreen} ${CClear}${InvDkGray}${CWhite} %s%s${CClear} | T1 Outer     | %-6.6s |${t1_color} %-12.12s ${CClear}| %15.15s | %-19.19s | %s\n" \
    "$t1_type_disp" "$DVPN_TUNNEL1_SLOT" "$DVPN_TUNNEL1_IF" "${t1_label}" "${t1_ep_disp}" "${t1_detail}" "${hop_ips_disp}"
  printf "${InvGreen} ${CClear}${InvDkGray}${CWhite} %s%s${CClear} | T2 Inner     | %-6.6s |${t2_color} %-12.12s ${CClear}| %15.15s | %-19.19s | Mark: %s -> Table %s\n" \
    "$t2_type_disp" "$DVPN_TUNNEL2_SLOT" "$DVPN_TUNNEL2_IF" "${t2_label}" "${t2_ep_disp}" "${t2_detail}" "${DVPN_HOP_MARK}" "${DVPN_TUNNEL2_TABLE}"
  echo ""
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_validate_ip_entry - validate a single IP/CIDR/range entry
# Returns 0 if valid, 1 if invalid

dvpn_validate_ip_entry()
{
  local entry="$1"
  local fmt
  fmt=$(dvpn_ip_format "$entry")

  case "$fmt" in
    single)
      # Check each octet is 0-255
      local a b c d
      IFS='.' read -r a b c d <<EOF
$entry
EOF
      for octet in "$a" "$b" "$c" "$d"; do
        echo "$octet" | grep -qE '^[0-9]+$' || return 1
        [ "$octet" -le 255 ] 2>/dev/null || return 1
      done
      return 0
      ;;
    cidr)
      local ip prefix
      ip=$(echo "$entry" | cut -d/ -f1)
      prefix=$(echo "$entry" | cut -d/ -f2)
      dvpn_validate_ip_entry "$ip" || return 1
      echo "$prefix" | grep -qE '^[0-9]+$' || return 1
      [ "$prefix" -le 32 ] 2>/dev/null && return 0
      return 1
      ;;
    range)
      local start end
      start=$(echo "$entry" | cut -d- -f1)
      end=$(echo "$entry" | cut -d- -f2)
      dvpn_validate_ip_entry "$start" || return 1
      dvpn_validate_ip_entry "$end"   || return 1
      [ "$(dvpn_ip_to_int "$start")" -le "$(dvpn_ip_to_int "$end")" ] && return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_detect_wg_slots - echo space-separated list of configured WG slot numbers
# A slot is considered "configured" if its NVRAM endpoint is non-empty.

dvpn_detect_wg_slots()
{
  local slots="" s ep
  for s in 1 2 3 4 5; do
    ep=$(nvram get "wgc${s}_ep_addr" 2>/dev/null)
    [ -n "$ep" ] && slots="$slots $s"
  done
  echo "$slots"
}


# -------------------------------------------------------------------------------------------------------------------------
# dvpn_detect_ovpn_slots - echo space-separated list of configured OVPN slot numbers

dvpn_detect_ovpn_slots()
{
  local slots="" s addr
  for s in 1 2 3 4 5; do
    addr=$(nvram get "vpn_client${s}_addr" 2>/dev/null)
    [ -n "$addr" ] && slots="$slots $s"
  done
  echo "$slots"
}


# -------------------------------------------------------------------------------------------------------------------------
# dvpn_derive_iface - echo interface name from type+slot

dvpn_derive_iface()
{
  local type="$1" slot="$2"
  [ "$type" = "wg" ] && echo "wgc${slot}" || echo "tun1${slot}"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_derive_table - echo routing table number from type+slot
# WG slots use tables 201-205; OVPN slots use tables 206-210 to avoid Merlin's 111-115 range

dvpn_derive_table()
{
  local type="$1" slot="$2"
  [ "$type" = "wg" ] && echo "$((200 + slot))" || echo "$((205 + slot))"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_setup - Double-Hop VPN configuration page

dvpn_setup()
{
  local action

  while true; do
    clear
    echo -e "${InvGreen} ${InvDkGray}${CWhite} Double-Hop VPN Setup                                                                  ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} This feature routes selected LAN clients through two nested VPN tunnels, giving you${CClear}"
    echo -e "${InvGreen} ${CClear} double encryption where neither provider sees both your origin and destination, when${CClear}"
    echo -e "${InvGreen} ${CClear} using 2 different VPN providers. If you only use 1 VPN provider, this feature will${CClear}"
    echo -e "${InvGreen} ${CClear} only obfuscate traffic for those intercepting.${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} Tunnel 1 (outer) connects to WAN. Tunnel 2 (inner) rides inside Tunnel 1. You have${CClear}"
    echo -e "${InvGreen} ${CClear} a choice between choosing a single client IP, or a range of IPs using either a start${Clear}"
    echo -e "${InvGreen} ${CClear} and an end, or using CIDR notation. Nesting VPN tunnels works seamlessly between${CClear}"
    echo -e "${InvGreen} ${CClear} WG -> OVPN, OVPN -> WG, WG -> WG, or OVPN -> OVPN.${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo -e "${InvGreen} ${CClear}"

    # Live routing state
    local route_state route_color
    if [ -f "$DVPN_STATE_FILE" ]; then
      . "$DVPN_STATE_FILE" 2>/dev/null
      if [ "$ST1_UP" = "1" ] && [ "$ST2_UP" = "1" ]; then
        if dvpn_routing_intact 2>/dev/null; then
          route_state="Rules active"
          route_color="$CGreen"
        else
          route_state="Rules incomplete (rebuild needed)"
          route_color="$CYellow"
        fi
      elif [ "$ST1_UP" = "1" ] || [ "$ST2_UP" = "1" ]; then
        route_state="Partial — one tunnel down"
        route_color="$CYellow"
      else
        route_state="No rules installed (tunnels down)"
        route_color="$CDkGray"
      fi
    else
      route_state="No rules installed"
      route_color="$CDkGray"
    fi

    local en_disp en_color
    if [ "$DVPN_ENABLED" = "1" ]; then
      en_color="$CGreen"; en_disp="Enabled"
    else
      en_color="$CRed";   en_disp="Disabled"
    fi

    local t1_type_disp t2_type_disp
    [ "$DVPN_TUNNEL1_TYPE" = "wg" ] && t1_type_disp="WireGuard" || t1_type_disp="OpenVPN"
    [ "$DVPN_TUNNEL2_TYPE" = "wg" ] && t2_type_disp="WireGuard" || t2_type_disp="OpenVPN"

    echo -e "${InvGreen} ${CClear} Feature          : ${en_color}${en_disp}${CClear}"
    echo -e "${InvGreen} ${CClear} Routing          : ${route_color}${route_state}${CClear}"
    echo -e "${InvGreen} ${CClear} Tunnel 1 (Outer) : ${CGreen}${t1_type_disp} Slot ${DVPN_TUNNEL1_SLOT}${CWhite}  (${DVPN_TUNNEL1_IF} -> table ${DVPN_TUNNEL1_TABLE})${CClear}"
    echo -e "${InvGreen} ${CClear} Tunnel 2 (Inner) : ${CGreen}${t2_type_disp} Slot ${DVPN_TUNNEL2_SLOT}${CWhite}  (${DVPN_TUNNEL2_IF} -> table ${DVPN_TUNNEL2_TABLE})${CClear}"
    echo -e "${InvGreen} ${CClear} Hop Clients      : ${CGreen}${DVPN_HOP_IPS:-"(none configured)"}${CClear}"
    echo -e "${InvGreen} ${CClear} Hop Mark         : ${CDkGray}${DVPN_HOP_MARK}${CClear}"
    echo -e "${InvGreen} ${CClear} WG Stale HS      : ${CDkGray}>${DVPN_WG_MAX_AGE}s treated as DOWN${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Enable / Disable DH Routing"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Configure Tunnel 1 (Outer)"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Configure Tunnel 2 (Inner)"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Configure Hop Client IPs"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Advanced Settings"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(6)${CClear} : Force Rebuild Rules Now"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(7)${CClear} : Remove DH Routing Rules"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(8)${CClear} : Run Diagnostics"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit to Configuration Menu"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    read -p "Please select (1-8, e=Exit): " action

    case "$action" in

      # 1: Toggle enable
      1)
        while true
        do
          if [ $DVPN_ENABLED -eq 1 ]; then en_disp="${CGreen}Enabled"; else en_disp="${CRed}Disabled"; fi
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Enable / Disable Double-Hop VPN Feature                                               ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate below if you would like to Enable or Disable the Double-Hop VPN${CClear}"
          echo -e "${InvGreen} ${CClear} feature. Enabling this feature will allow you to view a new section on the main${CClear}"
          echo -e "${InvGreen} ${CClear} VPNMON-R3 interface providing Double-Hop stats. Once enabled, you can automatically${CClear}"
          echo -e "${InvGreen} ${CClear} apply routing rules.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Disabling this feature will keep routing rules in place until you forcibly remove${CClear}"
          echo -e "${InvGreen} ${CClear} the routing rules using menu option (7) (Remove DH Routing Rules).${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Current Double-Hop VPN Feature: $en_disp${CClear}"
          echo ""
          if promptyn "Proceed to Enable/Disable Double-Hop VPN Feature? [y/n]: "
            then
              if [ "$DVPN_ENABLED" = "1" ]; then
                DVPN_ENABLED=0
                dvpn_saveconfig
                echo ""
                echo ""
                echo -e "${CGreen}Double-Hop VPN disabled.${CClear}"
                echo -e "VPNMON-R3 will no longer manage or monitor the routing rules. Any rules currently${CClear}"
                echo -e "installed remain active until you use option (7) to remove them.${CClear}"
                echo ""
                read -rsp $'Press any key to continue...\n' -n1 key
              else
                if [ -z "$DVPN_HOP_IPS" ]; then
                  echo ""
                  echo -e "${CRed}Cannot enable Double-Hop VPN — no Hop Client IPs configured. Use option (4) to add"
                  echo -e "at least one Hop Client IP first.${CClear}"
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
                else
                  DVPN_ENABLED=1
                  dvpn_saveconfig
                  echo ""
                  echo ""
                  echo -e "${CGreen}Double-Hop VPN enabled.${CClear}"
                  echo ""
                  # Offer immediate apply if both tunnels appear to be up already
                  local t1_up=0 t2_up=0
                  dvpn_tunnel_is_up "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT" && t1_up=1
                  dvpn_tunnel_is_up "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT" && t2_up=1
                  if [ "$t1_up" = "1" ] && [ "$t2_up" = "1" ]; then
                    echo -e "${CGreen}Both tunnels are currently UP.${CClear}"
                    echo ""
                    read -p "Apply routing rules now? [y/n]: " immediate
                    case "$immediate" in
                      [Yy]*)
                        echo ""
                        echo -e "Applying routing rules...${CClear}"
                        rm -f "$DVPN_STATE_FILE"
                        dvpn_check_and_apply
                        echo ""
                        echo -e "${CGreen}Done. Routing is now active.${CClear}"
                        echo ""
                        read -rsp $'Press any key to continue...\n' -n1 key
                        ;;
                      *)
                        echo ""
                        echo -e "Skipped. Rules will be applied on the next timer loop.${CClear}"
                        echo ""
                        read -rsp $'Press any key to continue...\n' -n1 key
                        ;;
                    esac
                  else
                    echo -e "${CYellow}One or both tunnels are currently DOWN.${CClear}"
                    echo -e "Rules will be installed automatically once both come up.${CClear}"
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  fi
                fi
              fi
            else
              break
          fi
        done
        ;;

      # 2: Configure Tunnel 1
      2)
        dvpn__config_tunnel 1
        ;;

      # 3: Configure Tunnel 2
      3)
        dvpn__config_tunnel 2
        ;;

      # 4: Configure hop client IPs
      4)
        dvpn__config_hop_ips
        ;;

      # 5: Advanced settings
      5)
        dvpn__config_advanced
        ;;

      # 6: Force rebuild
      6)
        echo ""
        echo -e "${CWhite}Force Rebuild DH Rules${CClear}"
        echo ""
        if [ "$DVPN_ENABLED" != "1" ]; then
          echo -e "${CGreen}Double-Hop is currently disabled.${CClear}"
          echo -e "Rules will be rebuilt and added but the script will not monitor or maintain them${CClear}"
          echo -e "until you enable the feature.${CClear}"
          echo ""
        fi
        echo -e "${CGreen}Rebuilding...${CClear}"
        rm -f "$DVPN_STATE_FILE"
        dvpn_check_and_apply
        echo ""
        echo -e "${CGreen}Rebuild complete.${CClear}"
        echo -e "Check the status line at the top of this feature menu, or use option (8) to run a${CClear}"
        echo -e "full diagnostic to validate.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        ;;

      # 7: Tear down
      7)
       while true
        do
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Tear Down Routing Rules                                                               ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate below if you would like to tear down and remove all Double-Hop${CClear}"
          echo -e "${InvGreen} ${CClear} Routing Rules. This is the last step that you would need to take when disabling${CClear}"
          echo -e "${InvGreen} ${CClear} the Double-Hop functionality. This removes all Double-Hop routing rules (ip rules,${CClear}"
          echo -e "${InvGreen} ${CClear} routing tables, iptables marks) and restores any VPN Director rules that were${CClear}"
          echo -e "${InvGreen} ${CClear} suspended. Your VPN tunnels themselves are not affected — only the Double-Hop${CClear}"
          echo -e "${InvGreen} ${CClear} routing layer is removed.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} In other cases, you may want to perform this step when troubleshooting, and${CClear}"
          echo -e "${InvGreen} ${CClear} need a complete refresh of the rules, which would need to be followed up with${CClear}"
          echo -e "${InvGreen} ${CClear} Option (6), Force Rebuild DH Rules.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          read -p "Proceed with teardown? [y/n]: " confirm
          case "$confirm" in
            [Yy]*)
            echo ""
            echo -e "${CGreen}Tearing down...${CClear}"
            dvpn_nuke_orphans 2>/dev/null
            dvpn_tunnel2_down 2>/dev/null
            dvpn_tunnel1_down 2>/dev/null
            rm -f "$DVPN_STATE_FILE"
            echo ""
            echo -e "${CGreen}Tear Down Complete.${CClear}"
            echo -e "All Double-Hop routing rules removed. VPN Director rules have been restored (if any).${CClear}"
            if [ "$DVPN_ENABLED" = "1" ]; then
              echo ""
              echo -e "${CGreen}Double-Hop is still enabled.${CClear}"
              echo -e "Rules will be reinstalled automatically when both tunnels are up, or use option (6)${CClear}"
              echo -e "to force a rebuild now.${CClear}"
            fi
            echo ""
            read -rsp $'Press any key to continue...\n' -n1 key
            break
            ;;
          *)
            echo ""
            echo -e "${CGreen}Teardown cancelled.${CClear}"
            echo ""
            read -rsp $'Press any key to continue...\n' -n1 key
            break
            ;;
          esac
        done
      ;;

      # 8: Run diagnostics
      8)
        dvpn__run_diagnostics
        ;;

      [Ee])
        return
        ;;

      *)
        ;;
    esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_find_wg - locate the wg binary and echo its full path, or empty if not found.
# Called once per function that needs it rather than stored globally, so it
# always reflects the current filesystem state (e.g. after Entware mounts).

dvpn_find_wg()
{
  local candidate
  for candidate in /usr/sbin/wg /usr/bin/wg /sbin/wg /bin/wg /opt/bin/wg /opt/sbin/wg; do
    [ -x "$candidate" ] && { echo "$candidate"; return; }
  done
  # Last resort: PATH search
  local p
  p=$(which wg 2>/dev/null)
  [ -n "$p" ] && echo "$p"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_wg_latest_hs - echo the most recent handshake epoch for a WG interface, or "0" if unavailable. Uses the resolved wg binary path.
# Output: integer Unix timestamp, or 0 on any failure.

dvpn_wg_latest_hs()
{
  local iface="$1"
  local wgbin hs

  wgbin=$(dvpn_find_wg)
  if [ -z "$wgbin" ]; then
    dvpn_log "ERROR: wg binary not found -- cannot check handshake for $iface"
    echo "0"; return
  fi

  hs=$("$wgbin" show "$iface" latest-handshakes 2>/dev/null | awk '{print $2}' | head -1)
  [ -z "$hs" ] && hs="0"
  echo "$hs"
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_wg_iface_exists - confirm a WireGuard interface is present and live.
# WireGuard interfaces report "state UNKNOWN" (not "state UP") in ip-link, so we check only for interface existence, not the state string.

dvpn_wg_iface_exists()
{
  local iface="$1"
  ip link show "$iface" > /dev/null 2>&1
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn_wg_slot_status - return UP or DOWN for a WireGuard slot.
# UP requires: interface exists (state UNKNOWN is normal for WG) AND most recent handshake is within DVPN_WG_MAX_AGE seconds.
# If the wg binary is missing entirely, falls back to interface-only detection and logs a warning so the operator knows the check is degraded.

dvpn_wg_slot_status()
{
  local slot="$1"
  local iface="wgc${slot}"

  # Step 1: interface must exist (WG shows as UNKNOWN, not UP - check existence only)
  if ! dvpn_wg_iface_exists "$iface"; then
    echo "DOWN"; return
  fi

  # Step 2: check handshake age via wg binary
  local wgbin
  wgbin=$(dvpn_find_wg)

  if [ -z "$wgbin" ]; then
    # wg binary unavailable - degrade gracefully: interface exists -> assume UP,
    dvpn_log "WARNING: wg binary not found -- $iface UP status based on interface only (no handshake check)"
    echo "UP"; return
  fi

  local hs now age
  hs=$(dvpn_wg_latest_hs "$iface")

  if [ "$hs" = "0" ]; then
    # Interface exists but no handshake yet (just connected, or no peers)
    echo "DOWN"; return
  fi

  now=$(date +%s)
  age=$(( now - hs ))
  [ "$age" -le "$DVPN_WG_MAX_AGE" ] && echo "UP" || echo "DOWN"
}


# -------------------------------------------------------------------------------------------------------------------------
# dvpn_ovpn_slot_status - return UP or DOWN for an OpenVPN slot.
# UP requires: nvram vpn_clientN_state = 2 AND tun1N interface exists.

dvpn_ovpn_slot_status()
{
  local slot="$1"
  local iface="tun1${slot}"
  local state

  state=$(nvram get "vpn_client${slot}_state" 2>/dev/null)
  [ "$state" != "2" ] && { echo "DOWN"; return; }
  ip link show "$iface" > /dev/null 2>&1 && echo "UP" || echo "DOWN"
}


# -------------------------------------------------------------------------------------------------------------------------
# dvpn__config_tunnel - sub-page: select type and slot for T1 or T2
# Usage: dvpn__config_tunnel <1|2>

dvpn__config_tunnel()
{
  local tunnel_num="$1"
  local other_num other_type other_slot other_label

  if [ "$tunnel_num" = "1" ]; then
    other_num="2"
    other_type="$DVPN_TUNNEL2_TYPE"
    other_slot="$DVPN_TUNNEL2_SLOT"
    other_label="T2"
  else
    other_num="1"
    other_type="$DVPN_TUNNEL1_TYPE"
    other_slot="$DVPN_TUNNEL1_SLOT"
    other_label="T1"
  fi

  local label
  [ "$tunnel_num" = "1" ] && label="Tunnel 1 (Outer)" || label="Tunnel 2 (Inner)"

  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Double-Hop VPN - Configure ${label}                                           ${CClear}"
  echo -e "${InvGreen} ${CClear}"

  # Build the numbered menu
  # Each entry: index | type | slot | status | in_use_flag | display_ep

  local idx=0
  # Parallel space-separated lists (positional, same index in each)
  local all_types=""   # "wg" or "ovpn"
  local all_slots=""   # "1".."5"

  # Collect WG slots
  local wg_slots s ep addr status_str status_color in_use_note
  wg_slots=$(dvpn_detect_wg_slots)
  for s in $wg_slots; do
    idx=$(( idx + 1 ))
    all_types="${all_types} wg"
    all_slots="${all_slots} ${s}"

    ep=$(nvram get "wgc${s}_ep_addr" 2>/dev/null | cut -d: -f1)
    status_str=$(dvpn_wg_slot_status "$s")
    [ "$status_str" = "UP" ] && status_color="$CGreen" || status_color="$CRed"

    in_use_note=""
    if [ "$other_type" = "wg" ] && [ "$other_slot" = "$s" ]; then
      in_use_note="  [in use as ${other_label}]"
    fi

    printf "${InvGreen} ${CClear}  ${InvDkGray}${CWhite}(%1d)${CClear}  WireGuard   Slot %s  ${status_color}%-4s${CClear}  ${CDkGray}%s${CClear}%s\n" \
    "$idx" "$s" "$status_str" "$ep" "$in_use_note"
  done

  # Collect OVPN slots
  local ovpn_slots
  ovpn_slots=$(dvpn_detect_ovpn_slots)
  for s in $ovpn_slots; do
    idx=$(( idx + 1 ))
    all_types="${all_types} ovpn"
    all_slots="${all_slots} ${s}"

    addr=$(nvram get "vpn_client${s}_addr" 2>/dev/null)
    status_str=$(dvpn_ovpn_slot_status "$s")
    [ "$status_str" = "UP" ] && status_color="$CGreen" || status_color="$CRed"

    in_use_note=""
    if [ "$other_type" = "ovpn" ] && [ "$other_slot" = "$s" ]; then
      in_use_note="  [in use as ${other_label}]"
    fi

    printf "${InvGreen} ${CClear}  ${InvDkGray}${CWhite}(%1d)${CClear}  OpenVPN     Slot %s  ${status_color}%-4s${CClear}  ${CDkGray}%s${CClear}%s\n" \
    "$idx" "$s" "$status_str" "$addr" "$in_use_note"
  done

  # Handle the no-slots-found case
  if [ "$idx" = "0" ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CRed}No configured VPN slots found.${CClear}"
    echo -e "${InvGreen} ${CClear}Set up WireGuard or OpenVPN clients in the router UI first.${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo ""
    read -rsp "Press any key to return..." -n1
    echo ""
    return
  fi

  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}  ${CDkGray}Note: DOWN slots can be selected - routing will be applied when they connect.${CClear}"
  if [ -n "$(echo "$all_types" | grep -o "wg\|ovpn" | head -1)" ]; then
    echo -e "${InvGreen} ${CClear}  ${CDkGray}[in use as Tx] means that slot is currently assigned to the other tunnel.${CClear}"
  fi
  echo -e "${InvGreen} ${CClear}"
  echo ""

  # Read and validate selection
  local choice valid=0
  while [ "$valid" = "0" ]; do
    read -p "Select slot for ${label} [1-${idx}, e=Exit]: " choice
    [ "$choice" = "e" ] || [ "$choice" = "E" ] && return
    if echo "$choice" | grep -qE '^[0-9]+$' && \
       [ "$choice" -ge 1 ] && [ "$choice" -le "$idx" ]; then
      valid=1
    else
      echo -e "${CRed}Invalid - enter a number between 1 and ${idx}.${CClear}"
    fi
  done

  # Extract selected type and slot from positional lists
  local sel_type="" sel_slot="" pos=0
  for t in $all_types; do
    pos=$(( pos + 1 ))
    if [ "$pos" = "$choice" ]; then sel_type="$t"; break; fi
  done
  pos=0
  for sl in $all_slots; do
    pos=$(( pos + 1 ))
    if [ "$pos" = "$choice" ]; then sel_slot="$sl"; break; fi
  done

  # Warn and confirm if selecting the slot already used by other tunnel ──
  if [ "$sel_type" = "$other_type" ] && [ "$sel_slot" = "$other_slot" ]; then
    echo ""
    echo -e "${CYellow}Warning: this slot is currently assigned to ${other_label}.${CClear}"
    echo -e "Assigning it here will clear ${other_label}'s slot assignment.${CClear}"
    echo -e "You will need to re-configure ${other_label} before enabling Double-Hop.${CClear}"
    echo ""
    read -p "Continue? (y/n): " confirm
    case "$confirm" in
      [Yy]*) ;;
      *) return ;;
    esac
    # Clear the other tunnel's slot so it's obviously unconfigured
    if [ "$other_num" = "1" ]; then
      DVPN_TUNNEL1_SLOT="" ; DVPN_TUNNEL1_IF="" ; DVPN_TUNNEL1_TABLE="" ; DVPN_TUNNEL1_MARK=""
    else
      DVPN_TUNNEL2_SLOT="" ; DVPN_TUNNEL2_IF="" ; DVPN_TUNNEL2_TABLE="" ; DVPN_TUNNEL2_MARK=""
    fi
  fi

  # Derive interface, table, and mark
  local sel_if sel_table sel_mark
  sel_if=$(dvpn_derive_iface "$sel_type" "$sel_slot")
  sel_table=$(dvpn_derive_table "$sel_type" "$sel_slot")
  sel_mark=$(printf "0x%X" "$sel_table")

  # Save to appropriate tunnel variables
  if [ "$tunnel_num" = "1" ]; then
    DVPN_TUNNEL1_TYPE="$sel_type"
    DVPN_TUNNEL1_SLOT="$sel_slot"
    DVPN_TUNNEL1_IF="$sel_if"
    DVPN_TUNNEL1_TABLE="$sel_table"
    DVPN_TUNNEL1_MARK="$sel_mark"
  else
    DVPN_TUNNEL2_TYPE="$sel_type"
    DVPN_TUNNEL2_SLOT="$sel_slot"
    DVPN_TUNNEL2_IF="$sel_if"
    DVPN_TUNNEL2_TABLE="$sel_table"
    DVPN_TUNNEL2_MARK="$sel_mark"
  fi

  dvpn_saveconfig
  rm -f "$DVPN_STATE_FILE"

  local disp_type
  [ "$sel_type" = "wg" ] && disp_type="WireGuard" || disp_type="OpenVPN"
  echo ""
  echo -e "${CGreen}${label} set to ${disp_type} Slot ${sel_slot} (${sel_if} -> table ${sel_table}).${CClear}"
  echo ""
  read -rsp $'Press any key to continue...\n' -n1 key
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn__config_hop_ips - collect double-hop client IP entries

dvpn__config_hop_ips()
{
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Double-Hop VPN - Hop Client IPs                                                       ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Enter the LAN IPs that should be routed through both tunnels.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}Accepted formats:${CClear}"
  echo -e "${InvGreen} ${CClear}   Single IP(s) : ${CGreen}192.168.50.197 (multiple standalone IPs allowed)${CClear}"
  echo -e "${InvGreen} ${CClear}   CIDR range   : ${CGreen}192.168.50.184/29${CClear}"
  echo -e "${InvGreen} ${CClear}   IP range     : ${CGreen}192.168.50.100-192.168.50.105${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Enter one entry per prompt using examples above. Leave blank to finish.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current entries: ${CGreen}${DVPN_HOP_IPS:-"(none)"}${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}  ${CDkGray}Press ENTER on a blank line to keep existing entries unchanged.${CClear}"
  echo -e "${InvGreen} ${CClear}  ${CDkGray}Type 'clear' to remove all entries and start over.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo ""

  local input
  read -p "Clear or Keep existing Hop Client IPs? (type: 'clear'/'keep', e=Exit): " input
  case "$input" in
    clear|CLEAR)
      DVPN_HOP_IPS=""
      echo ""
      echo -e "${CGreen}Existing entries cleared.${CClear}"
      ;;
    e|E)
      return
      ;;
  esac

  local count=0
  for _ in $DVPN_HOP_IPS; do count=$(( count + 1 )); done

  while true; do
    echo ""
    read -p "Entry $((count+1)) (blank=done): " input
    [ -z "$input" ] && break

    if dvpn_validate_ip_entry "$input"; then
      if [ -z "$DVPN_HOP_IPS" ]; then
        DVPN_HOP_IPS="$input"
      else
        DVPN_HOP_IPS="$DVPN_HOP_IPS $input"
      fi
      count=$(( count + 1 ))
      echo ""
      echo -e "${CGreen}Added: $input${CClear}"
    else
      echo ""
      echo -e "${CRed}Invalid format or range - please try again.${CClear}"
    fi
  done

  if [ "$count" = "0" ]; then
    echo ""
    echo -e "\n${CYellow}No entries - Double-Hop VPN will not be able to route any clients.${CClear}"
    echo ""
    read -rsp $'Press any key to continue...\n' -n1 key
    return
  fi

  dvpn_saveconfig
  rm -f "$DVPN_STATE_FILE"
  echo -e "\n${CGreen}Saved ${count} hop client entries.${CClear}"
  echo ""
  read -rsp $'Press any key to continue...\n' -n1 key
}

# -------------------------------------------------------------------------------------------------------------------------
# dvpn__config_advanced - advanced settings

dvpn__config_advanced()
{
  while true
  do
    clear
    echo -e "${InvGreen} ${InvDkGray}${CWhite} Double-Hop VPN - Advanced Settings                                                    ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} User-configurable Advanced Settings. ${CYellow}WARNING:${CClear} Leave these settings as-is if you do not${CClear}"
    echo -e "${InvGreen} ${CClear} understand what their purpose is.${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${CWhite}Current settings:${CClear}"
    echo -e "${InvGreen} ${CClear}   WG Handshake max age : ${CGreen}${DVPN_WG_MAX_AGE} seconds  ${CDkGray}(handshake older than this = tunnel DOWN)${CClear}"
    echo -e "${InvGreen} ${CClear}   Double-hop fwmark    : ${CGreen}${DVPN_HOP_MARK}${CClear}  ${CDkGray}(must not conflict with other marks)${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}   (Defaults: WG Handshake = 180 seconds, DH fwmark = 0x1CC)"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}   ${CDkGray}Use the enter key to accept currenty configured settings."
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    if promptyn "Proceed to modify Advanced Settings? [y/n]: "
      then
        echo ""
        echo ""
        local input
        read -p "WG handshake max age in seconds [${DVPN_WG_MAX_AGE}]: " input
        if [ -n "$input" ]; then
          if echo "$input" | grep -qE '^[0-9]+$' && [ "$input" -ge 30 ] && [ "$input" -le 600 ]; then
            DVPN_WG_MAX_AGE="$input"
            echo ""
            echo -e "${CGreen}Set to ${DVPN_WG_MAX_AGE}s.${CClear}"
          else
            echo ""
            echo -e "${CRed}Invalid - Please choose a value between 30-600. Keeping ${DVPN_WG_MAX_AGE}s.${CClear}"
          fi
        fi

        echo ""
        read -p "Double-hop fwmark (hex, e.g. 0x1CC) [${DVPN_HOP_MARK}]: " input
        if [ -n "$input" ]; then
          if echo "$input" | grep -qE '^0x[0-9a-fA-F]+$'; then
            DVPN_HOP_MARK="$input"
            echo ""
            echo -e "${CGreen}Set to ${DVPN_HOP_MARK}.${CClear}"
          else
            echo ""
            echo -e "${CRed}Invalid hex value. Keeping ${DVPN_HOP_MARK}.${CClear}"
          fi
        fi

        dvpn_saveconfig
        echo ""
        echo -e "${CGreen}Advanced settings saved.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
    else
      break
    fi
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# Double-Hop VPN Diagnostic functions - to verify double-hop routing is fully in place

pass() { echo -e "  ${CGreen}[PASS]${CClear} $*" ; PASS=$(( PASS + 1 )); }
warn() { echo -e "  ${CYellow}[WARN]${CClear} $*" ; WARN=$(( WARN + 1 )); }
fail() { echo -e "  ${CRed}[FAIL]${CClear} $*" ; FAIL=$(( FAIL + 1 )); }
info() { echo -e "  ${CDkGray}      ${CClear} $*" ; }
section() {
  echo ""
  echo -e "${InvGreen} ${InvDkGray}${CWhite} $* ${CClear}"
  echo ""
}

#Locate wg binary
find_wg() {
  local c
  for c in /usr/sbin/wg /usr/bin/wg /sbin/wg /bin/wg /opt/bin/wg /opt/sbin/wg; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  which wg 2>/dev/null
}

#IP format detection
ip_format() {
  local e="$1"
  echo "$e" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'   && { echo "cidr";   return; }
  echo "$e" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9.]+$'  && { echo "range";  return; }
  echo "$e" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'           && { echo "single"; return; }
  echo "invalid"
}

ip_to_int() {
  local a b c d
  IFS='.' read -r a b c d <<EOF
$1
EOF
  echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

# Expand an IP entry to a space-separated list of individual IPs
expand_entry() {
  local entry="$1" fmt
  fmt=$(ip_format "$entry")
  case "$fmt" in
    single) echo "$entry" ;;
    cidr)
      # Return the CIDR as-is for route-get testing; iptables uses it natively
      echo "$entry" ;;
    range)
      local start end s_int e_int cur ip
      start=$(echo "$entry" | cut -d- -f1)
      end=$(echo "$entry" | cut -d- -f2)
      s_int=$(ip_to_int "$start")
      e_int=$(ip_to_int "$end")
      cur=$s_int
      while [ "$cur" -le "$e_int" ]; do
        ip="$(( (cur>>24)&255 )).$(( (cur>>16)&255 )).$(( (cur>>8)&255 )).$(( cur&255 ))"
        echo "$ip"
        cur=$(( cur + 1 ))
      done
      ;;
  esac
}

check_iface() {
  local label="$1" iface="$2" type="$3" slot="$4"
  echo ""
  echo -e "  ${CWhite}${label} - ${iface}${CClear}"

  # Interface existence (WG shows UNKNOWN, not UP - test existence only)
  if ip link show "$iface" > /dev/null 2>&1; then
    local flags
    flags=$(ip link show "$iface" 2>/dev/null | head -1)
    pass "Interface exists: ${CDkGray}${flags}${CClear}"
  else
    fail "Interface $iface does not exist - tunnel is not connected"
    return 1
  fi

  # WireGuard-specific: handshake age
  if [ "$type" = "wg" ] && [ -n "$WGBIN" ]; then
    local hs now age peer
    peer=$("$WGBIN" show "$iface" peers 2>/dev/null | head -1)
    if [ -z "$peer" ]; then
      fail "No WireGuard peer found on $iface"
    else
      info "Peer: ${CDkGray}${peer}${CClear}"
      hs=$("$WGBIN" show "$iface" latest-handshakes 2>/dev/null | awk '{print $2}' | head -1)
      if [ -z "$hs" ] || [ "$hs" = "0" ]; then
        fail "No handshake recorded yet on $iface"
      else
        now=$(date +%s)
        age=$(( now - hs ))
        if [ "$age" -le "$DVPN_WG_MAX_AGE" ]; then
          pass "Handshake: ${CGreen}${age}s ago${CClear} (within ${DVPN_WG_MAX_AGE}s threshold)"
        else
          fail "Handshake: ${CRed}${age}s ago${CClear} - exceeds ${DVPN_WG_MAX_AGE}s threshold (tunnel stale)"
        fi
      fi
    fi

    # Transfer counters - confirms data is actually flowing
    local rx tx
    rx=$("$WGBIN" show "$iface" transfer 2>/dev/null | awk '{print $2}' | head -1)
    tx=$("$WGBIN" show "$iface" transfer 2>/dev/null | awk '{print $3}' | head -1)
    if [ -n "$rx" ] && [ "$rx" != "0" ]; then
      pass "Traffic flowing - RX: ${CGreen}${rx}B${CClear}  TX: ${tx}B"
    else
      warn "No transfer data recorded yet on $iface"
    fi

  elif [ "$type" = "ovpn" ]; then
    local state
    state=$(nvram get "vpn_client${slot}_state" 2>/dev/null)
    if [ "$state" = "2" ]; then
      pass "OpenVPN state: ${CGreen}2 (connected)${CClear}"
    else
      fail "OpenVPN state: ${CRed}${state}${CClear} (expected 2)"
    fi
  fi

  # IP address on interface
  local addr
  addr=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
  if [ -n "$addr" ]; then
    pass "Interface address: ${CCyan}${addr}${CClear}"
  else
    fail "No IPv4 address on $iface"
  fi
}

check_table() {
  local label="$1" table="$2" expected_if="$3" mark="$4" prio="$5"
  echo -e "  ${CWhite}${label} - table ${table}${CClear}"

  # Default route in table
  local def_route
  def_route=$(ip route show table "$table" 2>/dev/null | grep "^default")
  if [ -z "$def_route" ]; then
    fail "No default route in table ${table}"
  else
    if echo "$def_route" | grep -q "$expected_if"; then
      pass "Default route: ${CDkGray}${def_route}${CClear}"
    else
      fail "Default route in table ${table} does NOT go via ${expected_if}"
      info "Actual: $def_route"
    fi
  fi

  # ip rule for this table's fwmark
  local rule
  rule=$(ip rule show 2>/dev/null | grep "fwmark $mark" | grep "lookup $table")
  if [ -z "$rule" ]; then
    # Try hex/decimal variations
    rule=$(ip rule show 2>/dev/null | grep "$table" | grep -i "$mark")
  fi
  if [ -n "$rule" ]; then
    pass "ip rule: ${CDkGray}${rule}${CClear}"
  else
    fail "No ip rule found for fwmark ${mark} -> table ${table}"
  fi

  echo ""
}

dvpn__run_diagnostics()
{

#Result tracking
PASS=0
WARN=0
FAIL=0
CONF="/jffs/addons/vpnmon-r3.d/vr3dblvpn.cfg"
STATE="/tmp/doublevpn-state"

##############################################################################
# HEADER
##############################################################################
clear
echo ""
echo -e "${InvGreen} ${InvDkGray}${CWhite} Double-Hop VPN Diagnostic                                                             ${CClear}"
echo -e "${InvGreen} ${CClear}"
echo -e "${InvGreen} ${CClear}  Router   : $(nvram get lan_hostname 2>/dev/null)"
echo -e "${InvGreen} ${CClear}  WAN IP   : $(nvram get wan0_ipaddr 2>/dev/null)"
echo -e "${InvGreen} ${CClear}  Run time : $(date)"
echo -e "${InvGreen} ${CClear}"
echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"

##############################################################################
# SECTION 1 - Configuration
##############################################################################
section "1 of 7 - Configuration                                                               "

if [ ! -f "$CONF" ]; then
  fail "doublevpn.conf not found at $CONF"
  echo ""
  echo -e "  ${CRed}Cannot continue without configuration. Run the VPNMON-R3 setup menu first.${CClear}"
  echo ""; exit 1
fi

. "$CONF"
pass "Loaded config from $CONF"

if [ "$DVPN_ENABLED" != "1" ]; then
  fail "DVPN_ENABLED=$DVPN_ENABLED - Double-Hop is disabled in config"
  echo ""
  echo -e "  ${CYellow}Enable via the VPNMON-R3 setup menu before running this check.${CClear}"
  echo ""; exit 1
fi
pass "DVPN_ENABLED=1"

[ -z "$DVPN_HOP_IPS" ] && { fail "DVPN_HOP_IPS is empty - no hop clients configured"; } \
                       || { pass "Hop clients: ${CCyan}${DVPN_HOP_IPS}${CClear}"; }

echo ""
echo -e "  ${CWhite}Tunnel 1 (Outer):${CClear} ${DVPN_TUNNEL1_TYPE} Slot ${DVPN_TUNNEL1_SLOT} / ${DVPN_TUNNEL1_IF}  table ${DVPN_TUNNEL1_TABLE}  mark ${DVPN_TUNNEL1_MARK}"
echo -e "  ${CWhite}Tunnel 2 (Inner):${CClear} ${DVPN_TUNNEL2_TYPE} Slot ${DVPN_TUNNEL2_SLOT} / ${DVPN_TUNNEL2_IF}  table ${DVPN_TUNNEL2_TABLE}  mark ${DVPN_TUNNEL2_MARK}"
echo -e "  ${CWhite}Hop Mark:${CClear}         ${DVPN_HOP_MARK} -> table ${DVPN_TUNNEL2_TABLE}"
echo -e "  ${CWhite}WG Max HS Age:${CClear}    ${DVPN_WG_MAX_AGE}s"

echo ""
read -rsp $'Press any key to continue (2/7)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SECTION 2 - Interface Status
##############################################################################
section "2 of 7 - Interface Status                                                            "

WGBIN=$(find_wg)
if [ -z "$WGBIN" ]; then
  warn "wg binary not found - handshake checks will be skipped"
else
  pass "wg binary found: $WGBIN"
fi

check_iface "Tunnel 1 (Outer)" "$DVPN_TUNNEL1_IF" "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT"
check_iface "Tunnel 2 (Inner)" "$DVPN_TUNNEL2_IF" "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT"

echo ""
read -rsp $'Press any key to continue (3/7)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SECTION 3 - Endpoint Host Routes
##############################################################################
section "3 of 7 - Endpoint Host Routes                                                        "

echo -e "  ${CDkGray}T1 endpoint must be pinned to WAN (not via any tunnel).${CClear}"
echo -e "  ${CDkGray}T2 endpoint must be pinned through T1 (${DVPN_TUNNEL1_IF}), not WAN.${CClear}"
echo ""

# T1 endpoint -> WAN
T1_EP=$(dvpn_get_endpoint "$DVPN_TUNNEL1_TYPE" "$DVPN_TUNNEL1_SLOT")

if [ -z "$T1_EP" ]; then
  warn "Cannot determine T1 endpoint from NVRAM"
else
  echo -e "  ${CWhite}T1 endpoint: ${CCyan}${T1_EP}${CClear}"
  t1_route=$(ip route show "${T1_EP}/32" 2>/dev/null | head -1)
  if [ -z "$t1_route" ]; then
    fail "No host route found for T1 endpoint ${T1_EP}/32"
    info "Expected: ${T1_EP}/32 via <WAN_GW> dev <WAN_IF>"
  else
    # Confirm it goes via WAN and NOT through a tunnel interface
    if echo "$t1_route" | grep -qE "wgc|tun1"; then
      fail "T1 endpoint route goes through a tunnel interface - routing loop risk!"
      info "Route: $t1_route"
    else
      pass "T1 endpoint pinned to WAN: ${CDkGray}${t1_route}${CClear}"
    fi
  fi
fi

echo ""

# T2 endpoint -> via T1 interface
T2_EP=$(dvpn_get_endpoint "$DVPN_TUNNEL2_TYPE" "$DVPN_TUNNEL2_SLOT")

if [ -z "$T2_EP" ]; then
  warn "Cannot determine T2 endpoint from NVRAM"
else
  echo -e "  ${CWhite}T2 endpoint: ${CCyan}${T2_EP}${CClear}"
  t2_route=$(ip route show "${T2_EP}/32" 2>/dev/null | head -1)
  if [ -z "$t2_route" ]; then
    # Also check main table
    t2_route=$(ip route get "$T2_EP" 2>/dev/null | head -1)
  fi
  if [ -z "$t2_route" ]; then
    fail "No host route found for T2 endpoint ${T2_EP}"
    info "Expected: ${T2_EP}/32 dev ${DVPN_TUNNEL1_IF}"
  else
    if echo "$t2_route" | grep -q "$DVPN_TUNNEL1_IF"; then
      pass "T2 endpoint routed through T1 (${DVPN_TUNNEL1_IF}): ${CDkGray}${t2_route}${CClear}"
    else
      fail "T2 endpoint NOT routed through ${DVPN_TUNNEL1_IF}"
      info "Actual route: $t2_route"
      info "Expected via: $DVPN_TUNNEL1_IF"
    fi
  fi
fi

echo ""
read -rsp $'Press any key to continue (4/7)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SECTION 4 - Routing Tables
##############################################################################
section "4 of 7 - Routing Tables                                                              "

check_table "Tunnel 1 routing table" \
  "$DVPN_TUNNEL1_TABLE" "$DVPN_TUNNEL1_IF" "$DVPN_TUNNEL1_MARK" "$((9000 + DVPN_TUNNEL1_TABLE))"

check_table "Tunnel 2 routing table" \
  "$DVPN_TUNNEL2_TABLE" "$DVPN_TUNNEL2_IF" "$DVPN_TUNNEL2_MARK" "$((9000 + DVPN_TUNNEL2_TABLE))"

# Hop client fwmark rule -> T2 table
echo -e "  ${CWhite}Hop client rule - fwmark ${DVPN_HOP_MARK} -> table ${DVPN_TUNNEL2_TABLE}${CClear}"
hop_rule=$(ip rule show 2>/dev/null | grep -i "fwmark.*${DVPN_HOP_MARK}" | grep "lookup ${DVPN_TUNNEL2_TABLE}")
if [ -z "$hop_rule" ]; then
  hop_rule=$(ip rule show 2>/dev/null | grep "9000" | grep "${DVPN_TUNNEL2_TABLE}")
fi
if [ -n "$hop_rule" ]; then
  pass "Hop rule: ${CDkGray}${hop_rule}${CClear}"
else
  fail "No ip rule found for hop mark ${DVPN_HOP_MARK} -> table ${DVPN_TUNNEL2_TABLE}"
  info "This is the critical rule - without it hop clients go to the wrong table"
fi

echo ""
read -rsp $'Press any key to continue (5/7)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SECTION 5 - iptables Mangle Rules
##############################################################################
section "5 of 7 - iptables Mangle Rules                                                       "

echo -e "  ${CDkGray}Each hop client IP must have a PREROUTING mark rule setting ${DVPN_HOP_MARK}.${CClear}"
echo -e "  ${CDkGray}Each hop client IP must have FORWARD TCPMSS clamp rules for MSS 1300.${CClear}"
echo ""

for entry in $DVPN_HOP_IPS; do
  echo -e "  ${CWhite}Entry: ${CCyan}${entry}${CClear}"
  fmt=$(ip_format "$entry")
  info "Format: $fmt"

  # PREROUTING mark check
  mark_rule=$(iptables -t mangle -L PREROUTING -n -v 2>/dev/null | grep -i "MARK\|mark" | grep "$entry")
  if [ -z "$mark_rule" ]; then
    # For ranges, check iprange module match
    mark_rule=$(iptables -t mangle -L PREROUTING -n -v 2>/dev/null | grep -i "MARK\|mark" | grep -i "iprange")
    if [ -n "$mark_rule" ] && [ "$fmt" = "range" ]; then
      pass "PREROUTING mark rule present (iprange): ${CDkGray}${mark_rule}${CClear}"
    else
      fail "No PREROUTING mangle mark rule found for $entry"
      info "Hop client traffic will NOT be marked - it will bypass double-hop entirely"
    fi
  else
    pass "PREROUTING mark rule: ${CDkGray}$(echo "$mark_rule" | tr -s ' ')${CClear}"
  fi

  # FORWARD MSS clamp check
  mss_rule=$(iptables -t mangle -L FORWARD -n -v 2>/dev/null | grep "TCPMSS\|tcpmss" | grep "$entry")
  if [ -z "$mss_rule" ] && [ "$fmt" = "range" ]; then
    mss_rule=$(iptables -t mangle -L FORWARD -n -v 2>/dev/null | grep "TCPMSS\|tcpmss" | grep -i "iprange")
  fi
  if [ -n "$mss_rule" ]; then
    pass "FORWARD TCPMSS clamp rule present"
  else
    warn "No TCPMSS MSS clamp rule found for $entry"
    info "Large packets may be fragmented or dropped - browsing/streaming may suffer"
  fi

  echo ""
done

read -rsp $'Press any key to continue (6/7)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SECTION 6 - End-to-End Routing Chain Proof Per Hop Client
##############################################################################
section "6 of 7 - End-to-End Routing Chain Proof Per Hop Client                               "

echo -e "  ${CDkGray}Verifies the complete routing chain and that nothing overrides it.${CClear}"
echo ""
echo -e "  ${CWhite}Chain: [no conflicting rule] -> [from hop-IP rule prio 99 -> table ${DVPN_TUNNEL2_TABLE}] -> [table ${DVPN_TUNNEL2_TABLE} -> ${DVPN_TUNNEL2_IF}]${CClear}"
echo ""

WAN_IF=$(ip route show default table main 2>/dev/null | \
         awk '/^default/ && ($0 !~ /wgc/ && $0 !~ /tun/) {print $5; exit}')
WAN_IP=$(nvram get wan0_ipaddr 2>/dev/null)

for entry in $DVPN_HOP_IPS; do
  echo -e "  ${CWhite}--- Hop client: ${CCyan}${entry}${CWhite} ---${CClear}"
  echo ""
  chain_ok=0
  fmt=$(ip_format "$entry")

  # Link 0: no conflicting ip rule at a lower priority number
  echo -e "  ${CWhite}Link 0 - No overriding ip rule above priority ${DVPN_HOP_PRIO:-99}${CClear}"

  conflict_found=0
  case "$fmt" in
    single|cidr)
      while IFS= read -r crule; do
        [ -z "$crule" ] && continue
        cprio=$(echo "$crule" | awk -F: '{print $1}' | tr -d ' ')
        # Skip our own rule pointing to T2 table
        echo "$crule" | grep -q "lookup ${DVPN_TUNNEL2_TABLE}" && continue
        if [ -n "$cprio" ] && [ "$cprio" -lt "${DVPN_HOP_PRIO:-99}" ] 2>/dev/null; then
          conflict_found=1
          fail "Conflicting rule at priority ${cprio} overrides double-hop routing"
          info "Rule: ${CDkGray}${crule}${CClear}"
          info "This rule routes ${entry} before our priority-99 rule is reached"
          info "VPN Director likely rebuilt its rules after a tunnel reset"
        fi
      done <<EOF
$(ip rule show 2>/dev/null | grep "from $entry")
EOF
      ;;
    range)
      start=$(echo "$entry" | cut -d- -f1)
      while IFS= read -r crule; do
        [ -z "$crule" ] && continue
        cprio=$(echo "$crule" | awk -F: '{print $1}' | tr -d ' ')
        echo "$crule" | grep -q "lookup ${DVPN_TUNNEL2_TABLE}" && continue
        if [ -n "$cprio" ] && [ "$cprio" -lt "${DVPN_HOP_PRIO:-99}" ] 2>/dev/null; then
          conflict_found=1
          fail "Conflicting rule at priority ${cprio} for range start $start"
          info "Rule: ${CDkGray}${crule}${CClear}"
        fi
      done <<EOF
$(ip rule show 2>/dev/null | grep "from $start")
EOF
      ;;
  esac

  if [ "$conflict_found" = "0" ]; then
    pass "No overriding ip rules found above priority ${DVPN_HOP_PRIO:-99}"
    chain_ok=$(( chain_ok + 1 ))
  fi

  echo ""

  # Link 1: direct from-IP rule at DVPN_HOP_PRIO -> T2 table
  echo -e "  ${CWhite}Link 1 - ip rule: from ${entry} -> table ${DVPN_TUNNEL2_TABLE} (prio ${DVPN_HOP_PRIO:-99})${CClear}"

  direct_rule=""
  case "$fmt" in
    single|cidr)
      direct_rule=$(ip rule show 2>/dev/null | \
                    grep "^${DVPN_HOP_PRIO:-99}:.*from ${entry}.*lookup ${DVPN_TUNNEL2_TABLE}")
      ;;
    range)
      start=$(echo "$entry" | cut -d- -f1)
      direct_rule=$(ip rule show 2>/dev/null | \
                    grep "^${DVPN_HOP_PRIO:-99}:.*from ${start}.*lookup ${DVPN_TUNNEL2_TABLE}")
      ;;
  esac

  if [ -n "$direct_rule" ]; then
    pass "Direct routing rule: ${CDkGray}${direct_rule}${CClear}"
    chain_ok=$(( chain_ok + 1 ))
  else
    fail "No direct from-IP rule at priority ${DVPN_HOP_PRIO:-99} -> table ${DVPN_TUNNEL2_TABLE}"
    info "Rebuild routing via VPNMON-R3 setup -> Double-Hop -> option 6"
  fi

  echo ""

  # Link 2: table T2 default exits via DVPN_TUNNEL2_IF
  echo -e "  ${CWhite}Link 2 - table ${DVPN_TUNNEL2_TABLE} default route via ${DVPN_TUNNEL2_IF}${CClear}"

  t2_default=$(ip route show table "$DVPN_TUNNEL2_TABLE" 2>/dev/null | grep "^default")

  if [ -z "$t2_default" ]; then
    fail "Table ${DVPN_TUNNEL2_TABLE} has no default route"
  elif echo "$t2_default" | grep -q "$DVPN_TUNNEL2_IF"; then
    pass "Default route: ${CDkGray}${t2_default}${CClear}"
    chain_ok=$(( chain_ok + 1 ))
  elif echo "$t2_default" | grep -q "$DVPN_TUNNEL1_IF"; then
    fail "Table ${DVPN_TUNNEL2_TABLE} exits via ${DVPN_TUNNEL1_IF} (T1 only - single hop)"
    info "Route: $t2_default"
  elif [ -n "$WAN_IF" ] && echo "$t2_default" | grep -q "$WAN_IF"; then
    fail "Table ${DVPN_TUNNEL2_TABLE} exits via WAN - bypasses all VPN"
    info "Route: $t2_default"
  else
    warn "Unrecognised exit interface in table ${DVPN_TUNNEL2_TABLE}"
    info "Route: $t2_default"
  fi

  echo ""

  # Chain verdict
  if [ "$chain_ok" = "3" ]; then
    echo -e "  ${CGreen}Chain complete (3/3) - traffic from ${entry} is double-hopped${CClear}"
    echo -e "  ${CGreen}Exits via ${DVPN_TUNNEL2_IF} (T2) inside ${DVPN_TUNNEL1_IF} (T1)${CClear}"
  else
    echo -e "  ${CRed}Chain broken (${chain_ok}/3 links OK) - ${entry} is NOT correctly double-hopped${CClear}"
    if [ "$conflict_found" = "1" ]; then
      echo -e "  ${CYellow}VPN Director has overriding rules. Use option 6 to rebuild.${CClear}"
      echo -e "  ${CYellow}The integrity check will re-suspend them automatically on the next loop.${CClear}"
    else
      echo -e "  ${CYellow}Use VPNMON-R3 setup -> Double-Hop -> option 6 to rebuild routing.${CClear}"
    fi
  fi
  echo ""
done

read -rsp $'Press any key to continue (7/7)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SECTION 7 - State File
##############################################################################
section "7 of 7 - Runtime State                                                               "

if [ -f "$STATE" ]; then
  pass "State file present: $STATE"
  echo ""
  while IFS= read -r line; do
    info "$line"
  done < "$STATE"
  echo ""

  . "$STATE" 2>/dev/null
  if [ "$ST1_UP" = "1" ] && [ "$ST2_UP" = "1" ]; then
    pass "State: both tunnels UP - routing should be active"
  elif [ "$ST1_UP" = "1" ] && [ "$ST2_UP" = "0" ]; then
    fail "State: T1 UP but T2 DOWN - hop clients have no T2 exit"
  elif [ "$ST1_UP" = "0" ] && [ "$ST2_UP" = "0" ]; then
    fail "State: both tunnels DOWN - no double-hop routing active"
  else
    warn "State: unexpected combination ST1_UP=${ST1_UP} ST2_UP=${ST2_UP}"
  fi
else
  warn "State file not found at $STATE"
  info "dvpn_check_and_apply has not run yet, or state was cleared"
fi

echo ""
read -rsp $'Press any key to continue (Diagnostic Summary)... ' -n1 key
printf "\r\033[2K"

##############################################################################
# SUMMARY
##############################################################################
echo ""
echo -e "${InvGreen} ${InvDkGray}${CWhite} Diagnostic Summary                                                                    ${CClear}"
echo ""

TOTAL=$(( PASS + WARN + FAIL ))

echo -e "  ${CGreen}Passed : ${PASS}${CClear}"
echo -e "  ${CYellow}Warned : ${WARN}${CClear}"
echo -e "  ${CRed}Failed : ${FAIL}${CClear}"
echo -e "  ${CDkGray}Total  : ${TOTAL}${CClear}"
echo ""

if [ "$FAIL" = "0" ] && [ "$WARN" = "0" ]; then
  echo -e "  ${CGreen}All checks passed. Double-hop routing is fully operational.${CClear}"
  echo -e "  ${CDkGray}Verify from each hop client: curl -s https://api.ipify.org${CClear}"
  echo -e "  ${CDkGray}Returned IP should match T2 exit (not WAN, not T1).${CClear}"
elif [ "$FAIL" = "0" ]; then
  echo -e "  ${CYellow}Routing is active but review warnings above.${CClear}"
  echo -e "  ${CDkGray}Verify from each hop client: curl -s https://api.ipify.org${CClear}"
else
  echo -e "  ${CRed}One or more critical checks failed.${CClear}"
  echo -e "  ${CYellow}Try: VPNMON-R3 setup -> Double-Hop -> option 6 (Apply/Rebuild)${CClear}"
  echo -e "  ${CYellow}Then re-run this script.${CClear}"
fi

echo ""
echo -e "${CDkGray}  T1 exit (single-hop clients): should be IP of server ${T1_EP}${CClear}"
echo -e "${CDkGray}  T2 exit (double-hop clients): should be IP of server ${T2_EP}${CClear}"
echo -e "${CDkGray}  WAN IP (must NOT appear for any VPN client): ${WAN_IP}${CClear}"
echo ""
read -rsp $'Press any key to continue...\n' -n1 key

}

##-------------------------------------##
## Added by Martinski W. [2024-Oct-05] ##
##-------------------------------------##
_SetUpTimeoutCmdVars_()
{
   # If the timeout utility is available then use it #
   if [ -z "${timeoutcmd:+xSETx}" ] && [ -f "/opt/bin/timeout" ]
   then
       timeoutcmd="timeout "
       timeoutsec="10"
       timeoutlng="60"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2024-Oct-05] ##
##-------------------------------------##
_SetLAN_HostName_()
{
   [ -z "${LAN_HostName:+xSETx}" ] && \
   LAN_HostName="$($timeoutcmd$timeoutsec nvram get lan_hostname)"
}

_GetLAN_HostName_()
{ _SetLAN_HostName_ ; echo "$LAN_HostName" ; }

# -------------------------------------------------------------------------------------------------------------------------
# vsetup provide a menu interface to allow for initial component installs, uninstall, etc.

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-05] ##
##----------------------------------------##
vsetup()
{
   _SetUpTimeoutCmdVars_

while true
do
  clear # Initial Setup
  if [ ! -f "$config" ]; then # Write /jffs/addons/vpnmon-r3.d/vpnmon-r3.cfg
     saveconfig
  fi

  createconfigs

  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 Main Setup and Configuration Menu                                           ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to perform high level${CClear}"
  echo -e "${InvGreen} ${CClear} actions in the management of the VPNMON-R3 script.${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Custom configuration options for VPNMON-R3${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Force reinstall Entware dependencies${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Check for latest updates${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Uninstall VPNMON-R3${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-4, e=Exit): " SelectSlot
  case $SelectSlot in
      1) # Check for existence of entware, and if so proceed and install the timeout package, then run vpnmon-r3 -config
        clear
        if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]
        then
          vconfig
        else
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Dependencies                                                                  ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Missing dependencies required by VPNMON-R3 will be installed during this process."
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          echo -e "VPNMON-R3 has some dependencies in order to function correctly, namely, CoreUtils-Timeout"
          echo -e "JQ, and the Screen utility. These utilities require you to have Entware already installed"
          echo -e "using the AMTM tool. If Entware is present, the Timeout, JQ and Screen utilities will"
          echo -e "automatically be downloaded and installed during this process."
          echo ""
          echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
          echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router model."
          echo ""
          echo -e "${CGreen}JQuery${CClear} is a utility for querying data across the internet through the the means of"
          echo -e "APIs for the purposes of interacting with the various VPN providers to get a list"
          echo -e "of available VPN hosts in the selected location(s)."
          echo ""
          echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
          echo -e "directly on the router itself, instead of running your commands or a script from a network-"
          echo -e "attached SSH client. This can provide greater stability due to it running on the router"
          echo -e "itself."
          echo ""
          echo -e "Your router model is: ${CGreen}$ROUTERMODEL${CClear}"
          echo ""
          echo -e "Ready to install?"
          if promptyn "[y/n]: "
          then
              if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                echo ""
                echo -e "\n${CClear}Updating Entware Packages..."
                echo ""
                opkg update
                echo ""
                echo -e "Installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package...${CClear}"
                echo ""
                opkg install coreutils-timeout
                echo ""
                echo -e "Installing Entware ${CGreen}JQuery${CClear} Package...${CClear}"
                echo ""
                opkg install jq
                echo ""
                echo -e "Installing Entware ${CGreen}Screen${CClear} Package...${CClear}"
                echo ""
                opkg install screen
                echo ""
                echo -e "Install completed..."
                echo ""
                read -rsp $'Press any key to continue...\n' -n1 key
                echo ""
                echo -e "Executing Configuration Utility..."
                sleep 2
                vconfig
              else
                clear
                echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
                echo -e "Please install Entware using the AMTM utility before proceeding..."
                echo ""
                read -rsp $'Press any key to continue...\n' -n1 key
              fi
          else
              echo ""
              echo -e "\nExecuting Configuration Utility..."
              sleep 2
              vconfig
          fi
        fi
      ;;

      2) # Force re-install the CoreUtils timeout/screen package
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Re-install Dependencies                                                               ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Missing dependencies required by VPNMON-R3 will be re-installed during this process."
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "Would you like to re-install the CoreUtils-Timeout, JQ and the Screen utility? These"
        echo -e "utilities require you to have Entware already installed using the AMTM tool. If Entware"
        echo -e "is present, the Timeout and Screen utilities will be uninstalled, downloaded and re-"
        echo -e "installed during this setup process..."
        echo ""
        echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
        echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router"
        echo -e "model."
        echo ""
        echo -e "${CGreen}JQuery${CClear} is a utility for querying data across the internet through the the means of"
        echo -e "APIs for the purposes of interacting with the various VPN providers to get a list"
        echo -e "of available VPN hosts in the selected location(s)."
        echo ""
        echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
        echo -e "directly on the router itself, instead of running your commands or a script from a"
        echo -e "network-attached SSH client. This can provide greater stability due to it running on"
        echo -e "the router itself."
        echo ""
        echo -e "Your router model is: ${CGreen}$ROUTERMODEL${CClear}"
        echo ""
        echo -e "Force Re-install?"
        if promptyn "[y/n]: "
        then
            if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
              echo ""
              echo -e "\nUpdating Entware Packages..."
              echo ""
              opkg update
              echo ""
              echo -e "Force Re-installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package..."
              echo ""
              opkg install --force-reinstall coreutils-timeout
              echo ""
              echo -e "Force Re-installing Entware ${CGreen}JQuery${CClear} Package..."
              echo ""
              opkg install --force-reinstall . jq
              echo ""
              echo -e "Force Re-installing Entware ${CGreen}Screen${CClear} Package..."
              echo ""
              opkg install --force-reinstall screen
              echo ""
              echo -e "Re-install completed..."
              echo ""
              read -rsp $'Press any key to continue...\n' -n1 key
            else
              clear
              echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
              echo -e "Please install Entware using the AMTM utility before proceeding..."
              echo ""
              read -rsp $'Press any key to continue...\n' -n1 key
            fi
        fi
      ;;
      3) vupdate;;
      4) vuninstall;;
      [Ee])
            echo ""
            timer="$timerloop"
            break;;
    esac
done

}

# -------------------------------------------------------------------------------------------------------------------------
# vconfig is a function that provides a UI to choose various options for vpnmon-r3

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-05] ##
##----------------------------------------##
vconfig()
{
   _SetUpTimeoutCmdVars_

# Grab the VPNMON-R3 config file and read it in
if [ -f "$config" ]
then
  source "$config"
else
  clear
  echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
  echo ""
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
  echo -e "${CClear}"
  exit 1
fi

while true
do
  if [ "$availableslots" = "1 2" ]; then
     availableslotsdisp="2 x OVPN"
  elif [ "$availableslots" = "1 2 3 4 5" ]; then
     availableslotsdisp="5 x OVPN | 5 x WG"
  fi

  if [ "$unboundclient" -eq 0 ]; then
     unboundclientexp="${CDkGray}Disabled"
  else
     unboundclientexp="Enabled, VPN$unboundclient"
  fi

  if [ "$unboundwgclient" -eq 0 ]; then
     unboundwgclientexp="${CDkGray}Disabled"
  else
     unboundwgclientexp="Enabled, WGC$unboundwgclient"
  fi

  if [ "$unboundclient" -eq 0 ] && [ "$unboundwgclient" -eq 0 ]; then
    unboundshowip=0
    saveconfig
  fi

  if [ "$unboundshowip" -eq 0 ]; then
     unboundshowipdisp="${CDkGray}Disabled"
  else
     unboundshowipdisp="Enabled"
  fi

  if [ "$refreshserverlists" -eq 0 ]; then
     refreshserverlistsdisp="${CDkGray}Disabled"
  else
     refreshserverlistsdisp="Enabled"
  fi

  if [ "$monitorwan" -eq 0 ]; then
     monitorwandisp="${CDkGray}Disabled"
     wantimersdisp="${CDkGray}Disabled"
  else
     monitorwandisp="Enabled"
     wantimersdisp="${CGreen}$recoverytimer | $wandowntimer | $reconnecttimer sec"
  fi

  if [ "$useovpn" -eq 0 ] && [ "$usewg" -eq 0 ]; then
     useovpnwgDisp="${CDkGray}OVPN/WG Disabled"
  elif
     [ "$useovpn" -eq 1 ] && [ "$usewg" -eq 0 ]; then
     useovpnwgDisp="${CGreen}OVPN Only"
  elif
     [ "$useovpn" -eq 0 ] && [ "$usewg" -eq 1 ]; then
     useovpnwgDisp="${CGreen}WG Only"
  elif
     [ "$useovpn" -eq 1 ] && [ "$usewg" -eq 1 ]; then
     useovpnwgDisp="${CGreen}OVPN/WG Enabled"
  fi

  if [ "$updateskynet" -eq 0 ]; then
     updateskynetdisp="${CDkGray}Disabled"
  else
     updateskynetdisp="Enabled"
  fi

  if [ "$amtmemailsuccess" = "0" ] && [ "$amtmemailfailure" = "0" ]; then
     amtmemailsuccfaildisp="${CDkGray}Disabled"
  elif [ "$amtmemailsuccess" = "1" ] && [ "$amtmemailfailure" = "0" ]; then
     amtmemailsuccfaildisp="Success"
  elif [ "$amtmemailsuccess" = "0" ] && [ "$amtmemailfailure" = "1" ]; then
     amtmemailsuccfaildisp="Failure"
  elif [ "$amtmemailsuccess" = "1" ] && [ "$amtmemailfailure" = "1" ]; then
     amtmemailsuccfaildisp="Success, Failure"
  else
     amtmemailsuccfaildisp="Disabled"
  fi

  rldisp=""
  if [ "$amtmemailsuccess" = "1" ] || [ "$amtmemailfailure" = "1" ]
    then
      if [ "$ratelimit" = "0" ]; then
        rldisp="| ${CDkGray}RL"
      else
        rldisp="| ${CGreen}RL:$ratelimit/h"
      fi
  fi

  if [ "$rstspdmerlin" -eq 0 ]; then
     rstspdmerlindisp="${CDkGray}Disabled"
  else
     rstspdmerlindisp="Enabled"
  fi

  if [ "$selectionmethod" -eq 0 ]; then
     selectionmethoddisp="Random"
  elif [ "$selectionmethod" -eq 1 ]; then
     selectionmethoddisp="Sequential"
  fi

  if [ "$bwdisp" -eq 1 ]; then
     throughputmethoddisp="Average Throughput (in Mbps)"
  elif [ "$bwdisp" -eq 2 ]; then
     throughputmethoddisp="Total Throughput (in MB)"
  fi

  if [ "$DVPN_ENABLED" -eq 0 ]; then
     dvpnenableddisp="${CDkGray}Disabled"
  else
     dvpnenableddisp="Enabled"
  fi


  utilspddisp="${CGreen}RX: 0-->$lowutilspd${CGreen}|${CYellow}$lowutilspd-->$medutilspd${CGreen}|${CRed}$medutilspd-->Max${CClear}"
  utilspdupdisp="${CGreen}TX: 0-->$lowutilspdup${CGreen}|${CYellow}$lowutilspdup-->$medutilspdup${CGreen}|${CRed}$medutilspdup-->Max${CClear}"

  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 Configuration Options                                                       ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to modify certain${CClear}"
  echo -e "${InvGreen} ${CClear} customizable parameters that affect the operation of this script.${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 1)${CClear} : Number of VPN/WG Client Slots available      : ${CGreen}$availableslotsdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 2)${CClear} : Custom PING hosts for connectivity checks    : ${CGreen}$PINGHOST | $PINGHOST2"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 3)${CClear} : Custom Event Log size (rows)                 : ${CGreen}$logsize"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 4)${CClear} : Unbound DNS Lookups over VPN Integration     : ${CGreen}$unboundclientexp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 5)${CClear} : Unbound DNS Lookups over WG Integration      : ${CGreen}$unboundwgclientexp"
  if [ "$unboundclient" -ge 1 ] || [ "$unboundwgclient" -ge 1 ]; then
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 6)${CClear} -- Show Expanded Unbound IP Info?              : ${CGreen}$unboundshowipdisp"
  else
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 6)${CClear} -- ${CDkGray}Show Expanded Unbound IP Info?              : $unboundshowipdisp"
  fi
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 7)${CClear} : Refresh Custom Server Lists on -RESET Switch : ${CGreen}$refreshserverlistsdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 8)${CClear} : Provide additional WAN/Dual WAN monitoring   : ${CGreen}$monitorwandisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 9)${CClear} : Enable/Disable VPN/WG Slot Monitoring        : $useovpnwgDisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(10)${CClear} : Whitelist VPN Server IP Lists in Skynet      : ${CGreen}$updateskynetdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(11)${CClear} : AMTM Email Notifications / Rate Limiting     : ${CGreen}$amtmemailsuccfaildisp $rldisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(12)${CClear} : Reset spdMerlin Interfaces on VPN Reset      : ${CGreen}$rstspdmerlindisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(13)${CClear} : Server List Item Selection Method            : ${CGreen}$selectionmethoddisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(14)${CClear} : Connection Throughput Threshold Selections   : $utilspddisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}  |-${CClear}---                                             : $utilspdupdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(15)${CClear} : Connection Throughput Display Method         : ${CGreen}$throughputmethoddisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(16)${CClear} : WAN Recovery, Down, Reconnect Timers         : $wantimersdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(17)${CClear} : Double-Hop OVPN/WG configuration             : ${CGreen}$dvpnenableddisp${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}  | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-17, e=Exit): " SelectSlot
    case $SelectSlot in
      1)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Number of VPN/WG Client Slots Available on Router                                     ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate how many VPN/WG client slots your router is configured with. Certain${CClear}"
        echo -e "${InvGreen} ${CClear} older model routers (RT-AC68U) can only handle a maximum of 2 VPN client slots, and${CClear}"
        echo -e "${InvGreen} ${CClear} natively can't handle WG without some effort using 3rd party scripts, while the vast${CClear}"
        echo -e "${InvGreen} ${CClear} majority of newer models can handle 5 VPN and 5 WG slots. Easiest way to tell is by${CClear}"
        echo -e "${InvGreen} ${CClear} looking at your VPN settings within the Merlin Web UI. Please choose below:"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} ${CGreen}(2)${CClear} = 2 x VPN slots (Older router models)"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} ${CGreen}(5)${CClear} = 5 x VPN | 5 x WG slots (Newer router models)"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = 5 VPN/WG client slots)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$availableslotsdisp${CClear}" ; echo
        read -p "Please enter value (2 or 5)? (e=Exit): " newAvailableSlots
        if [ "$newAvailableSlots" = "2" ]
        then
            availableslots="1 2"
            availableslotsdisp="2 x VPN"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslotsdisp" >> $logfile
            rm -f /jffs/addons/vpnmon-r3.d/vr3clients.txt
            rm -f /jffs/addons/vpnmon-r3.d/vr3timers.txt
            saveconfig
            createconfigs
        elif [ "$newAvailableSlots" = "5" ]
        then
            availableslots="1 2 3 4 5"
            availableslotsdisp="5 x VPN | 5 x WG"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslotsdisp" >> $logfile
            rm -f /jffs/addons/vpnmon-r3.d/vr3clients.txt
            rm -f /jffs/addons/vpnmon-r3.d/vr3timers.txt
            saveconfig
            createconfigs
        elif [ "$newAvailableSlots" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            previousValue="$availableslots"
            availableslots="${availableslots:=1 2 3 4 5}"
            availableslotsdisp="5 x VPN | 5 x WG"
            [ "$availableslots" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslotsdisp" >> $logfile
            rm -f /jffs/addons/vpnmon-r3.d/vr3clients.txt
            rm -f /jffs/addons/vpnmon-r3.d/vr3timers.txt
            saveconfig
            createconfigs
        fi
      ;;

      2)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom PING Hosts (to determine WAN/VPN/WG health)                                    ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate which hosts you want to PING in order to determine connectivity${CClear}"
        echo -e "${InvGreen} ${CClear} health. By default, the script will ping 8.8.8.8 (Google DNS) and 1.1.1.1 (CloudFlare${CClear}"
        echo -e "${InvGreen} ${CClear} DNS) as they are reliable, fairly standard, and typically available globally. You can${CClear}"
        echo -e "${InvGreen} ${CClear} change these depending on your local access and connectivity situation. It is${CClear}"
        echo -e "${InvGreen} ${CClear} advisable to choose 2 different DNS provider IP addresses for redundancy purposes. If${CClear}"
        echo -e "${InvGreen} ${CClear} one fails to PING, the other will redundantly keep your connection from being reset.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = 8.8.8.8 | 1.1.1.1)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current Pinghost 1: ${CGreen}${PINGHOST}${CClear}"
        echo -e "${CClear}Current Pinghost 2: ${CGreen}${PINGHOST2}${CClear}" ; echo
        read -p "Please enter valid IPv4 address for Pinghost 1? (e=Exit): " newPingHost
        if [ "$newPingHost" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2; continue
        elif [ -n "$newPingHost" ] && echo "$newPingHost" | grep -qE "^${IPv4addrs_RegEx}$"
        then
            PINGHOST="$newPingHost"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New custom PING host 1 entered: $PINGHOST" >> $logfile
        else
            PINGHOST="8.8.8.8"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Default PING host 1 entered: $PINGHOST" >> $logfile
        fi
        echo ""
        read -p "Please enter valid IPv4 address for Pinghost 2? (e=Exit): " newPingHost2
        if [ "$newPingHost2" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        elif [ -n "$newPingHost2" ] && echo "$newPingHost2" | grep -qE "^${IPv4addrs_RegEx}$"
        then
            PINGHOST2="$newPingHost2"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New custom PING host 2 entered: $PINGHOST2" >> $logfile
            saveconfig
        else
            PINGHOST2="1.1.1.1"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Default PING host 2 entered: $PINGHOST2" >> $logfile
            saveconfig
        fi
      ;;

      3)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom Event Log Size                                                                 ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below how large you would like your Event Log to grow. I'm a poet${CClear}"
        echo -e "${InvGreen} ${CClear} and didn't even know it. By default, with 2000 rows, you will have many months of${CClear}"
        echo -e "${InvGreen} ${CClear} Event Log data."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 0 to Disable, max number of rows is 9999. (Default = 2000)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$logsize${CClear}" ; echo
        read -p "Please enter Log Size (in rows)? (0-9999, e=Exit): " newLogSize
        if [ "$newLogSize" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        elif echo "$newLogSize" | grep -qE "^(0|[1-9][0-9]{0,3})$" && \
            [ "$newLogSize" -ge 0 ] && [ "$newLogSize" -le 9999 ]
        then
            logsize="$newLogSize"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New custom Event Log Size entered (in rows): $logsize" >> $logfile
            saveconfig
        else
            previousValue="$logsize"
            logsize="${logsize:=2000}"
            [ "$logsize" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New custom Event Log Size entered (in rows): $logsize" >> $logfile
            saveconfig
        fi
      ;;

      4)

        if [ "$unboundwgclient" -ge 1 ]; then
          echo ""
          echo -e "${CRed}Unbound-over-WG is currently enabled. If you want to enable Unbound-over-VPN, please proceed to 'Disable'"
          echo -e "the Unbound-over-WG option first, then choose to enable Unbound-over-VPN.${CClear}"
          echo ""
          sleep 3
          read -rsp $'Press any key to continue...\n' -n1 key
          continue
        fi

        while true; do
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Unbound DNS Lookups over VPN Integration                                              ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate if you would like to enable an integration with Unbound which allows${CClear}"
          echo -e "${InvGreen} ${CClear} you to force any DNS lookups that Unbound would normally handle, but over your VPN${CClear}"
          echo -e "${InvGreen} ${CClear} connection, essentially allowing you to appear as your own DNS resolver. DNS resolver${CClear}"
          echo -e "${InvGreen} ${CClear} traffic generated by Unbound is unencrypted as it queries DNS Root Servers by default.${CClear}"
          echo -e "${InvGreen} ${CClear} This integration encrypts your DNS Resolver traffic up to your Public VPN IP address,${CClear}"
          echo -e "${InvGreen} ${CClear} after which it goes unencrypted to the DNS Root Servers, preventing any ISP or other${CClear}"
          echo -e "${InvGreen} ${CClear} traffic inspection snooping when sending this across your WAN connection.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} IMPORTANT: This integration will only work with 1 primary VPN connection that is${CClear}"
          echo -e "${InvGreen} ${CClear} designated as the connection that will carry DNS resolution traffic. This integration${CClear}"
          echo -e "${InvGreen} ${CClear} will work when multiple VPN connections are running, but the other VPN connections may${CClear}"
          echo -e "${InvGreen} ${CClear} not be able to utilize the Unbound functionality, and considered standalone. You will${CClear}"
          echo -e "${InvGreen} ${CClear} need to identify one VPN Client Slot that will remain on at all times. This integration${CClear}"
          echo -e "${InvGreen} ${CClear} requires additional scripts and configurations to get it working correctly. Please know${CClear}"
          echo -e "${InvGreen} ${CClear} that multiple files will either be downloaded or modified, and may increase the${CClear}"
          echo -e "${InvGreen} ${CClear} complexity in troubleshooting DNS lookup issues.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${CRed}WARNING: As of around March 1 2024, the Unbound integration no longer works with the${CClear}"
          echo -e "${InvGreen} ${CClear} ${CRed}NordVPN Service due to possible blocking on their end. This service continues to work${CClear}"
          echo -e "${InvGreen} ${CClear} ${CRed}as advertised with other VPN Providers, like AirVPN. Use at your own risk.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${CGreen}Requirements:"
          echo -e "${InvGreen} ${CClear} ${CGreen}1. Unbound must already be installed and functioning (AMTM)"
          echo -e "${InvGreen} ${CClear} ${CGreen}2. One static VPN Slot must be designated for Unbound-over-VPN use"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${CGreen}These files will be downloaded or modified:"
          echo -e "${InvGreen} ${CClear} ${CGreen}1. /jffs/scripts/nat-start (modified)"
          echo -e "${InvGreen} ${CClear} ${CGreen}2. /jffs/scripts/openvpn-event (modified)"
          echo -e "${InvGreen} ${CClear} ${CGreen}3. /jffs/scripts/post-mount (modified)"
          echo -e "${InvGreen} ${CClear} ${CGreen}4. /jffs/addons/unbound/unbound_DNS_via_OVPN.sh (downloaded)"
          echo -e "${InvGreen} ${CClear} ${CGreen}5. Required router reboot - please don't forget to do so!${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} (Default = 0 / Disabled)${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          if [ $unboundclient -eq 0 ]; then
            unboundclientexp="Disabled"
          else
            unboundclientexp="Enabled, VPN$unboundclient"
          fi

          echo -e "${CClear}Current: ${CGreen}$unboundclientexp${CClear}"
          echo ""
          read -p "Please enter value (Disabled=0, VPN Client=1-5)? (e=Exit): " unboundovervpn

          if [ ! -d "/jffs/addons/unbound" ]; then
            echo ""
            echo -e "${CRed}[Unbound was not detected on this system. Exiting...]${CClear}"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: Unbound was not detected on this system." >> $logfile
            unboundclient=0
            saveconfig
            sleep 3
            continue
          fi

          if [ "$unboundovervpn" = "0" ] || [ "$unboundovervpn" = "1" ] || [ "$unboundovervpn" = "2" ] || [ "$unboundovervpn" = "3" ] || [ "$unboundovervpn" = "4" ] || [ "$unboundovervpn" = "5" ] || [ "$unboundovervpn" = "e" ]; then
            if [ "$unboundovervpn" = "0" ]; then

              # Delete all additions made to files to enable Unbound over VPN functionality
              echo ""
              echo -e "${CGreen}[Disabling Unbound over VPN]...${CClear}"

              # Disable vpn functionality with Unbound
              sh /jffs/addons/unbound/unbound_manager.sh vpn=disable >/dev/null 2>&1

              # Remove Unbound failsafe in post-mount
              if [ -f /jffs/scripts/post-mount ]; then
                sed -i -e '/vpn=disable/d' /jffs/scripts/post-mount
              fi

              # Remove Unbound VPN helper script in openvpn-event
              if [ -f /jffs/scripts/openvpn-event ]; then
                sed -i -e '/unbound_DNS_via_OVPN.sh/d' /jffs/scripts/openvpn-event
              fi

              # Remove RPDB Rules added to nat-start
              if [ -f /jffs/scripts/nat-start ]; then
                sed -i -e '/Added by vpnmon/d' /jffs/scripts/nat-start
              fi

              # Remove the unbound_DNS_via_OVPN.sh file
              if [ -f /jffs/addons/unbound/unbound_DNS_via_OVPN.sh ]; then
                rm -f /jffs/addons/unbound/unbound_DNS_via_OVPN.sh
              fi

              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound-over-VPN was removed from VPNMON-R3" >> $logfile
              unboundclient=0
              saveconfig
              sleep 3
              continue

            elif [ "$unboundovervpn" = "1" ] || [ "$unboundovervpn" = "2" ] || [ "$unboundovervpn" = "3" ] || [ "$unboundovervpn" = "4" ] || [ "$unboundovervpn" = "5" ]; then

              if [ "$unboundovervpn" = "$unboundclient" ]; then
                echo -e "${CClear}\n[Unbound over VPN$unboundovervpn Already Active]"; sleep 2; break
              fi

              if [ "$unboundovervpn" = "1" ] || [ "$unboundovervpn" = "2" ] || [ "$unboundovervpn" = "3" ] || [ "$unboundovervpn" = "4" ] || [ "$unboundovervpn" = "5" ] && [ $unboundclient -ge 1 ]; then
                echo ""
                echo -e "${CRed}When changing a VPN Client Slot (from Slot #$unboundclient to Slot #$unboundovervpn), please proceed to 'Disable'"
                echo -e "first (option 0), then choose a new VPN Slot."
                sleep 5; continue
              fi

              # Modify or create post-mount
              if [ -f /jffs/scripts/post-mount ]; then

                if ! grep -q -F "[ -n "'"$(which unbound_manager)"'" ] && { sh /jffs/addons/unbound/unbound_manager.sh vpn=disable; }" /jffs/scripts/post-mount; then
                  echo "[ -n "'"$(which unbound_manager)"'" ] && { sh /jffs/addons/unbound/unbound_manager.sh vpn=disable; } # Added by vpnmon-r3" >> /jffs/scripts/post-mount
                fi

              else
                echo "#!/bin/sh" > /jffs/scripts/post-mount
                echo "" >> /jffs/scripts/post-mount
                echo "[ -n "'"$(which unbound_manager)"'" ] && { sh /jffs/addons/unbound/unbound_manager.sh vpn=disable; } # Added by vpnmon-r3" >> /jffs/scripts/post-mount
                chmod 755 /jffs/scripts/post-mount
              fi

              # Modify or create nat-start
              if [ -f /jffs/scripts/nat-start ]; then

                if ! grep -q -F "sleep 10  # During the boot process nat-start may run multiple times so this is required" /jffs/scripts/nat-start; then
                  echo "" >> /jffs/scripts/nat-start
                  echo "sleep 10  # During the boot process nat-start may run multiple times so this is required - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "" >> /jffs/scripts/nat-start
                  echo "# Ensure duplicate rules are not created - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "for VPN_ID in 0 1 2 3 4 5  # Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "  do  # Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "    ip rule del prio 999$VPN_ID  2>/dev/null  # Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "  done  # Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "" >> /jffs/scripts/nat-start
                  echo "# Create the RPDB rules - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "ip rule add from 0/0 fwmark \"0x8000/0x8000\" table main   prio 9990        # WAN   fwmark - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "ip rule add from 0/0 fwmark \"0x7000/0x7000\" table ovpnc4 prio 9991        # VPN 4 fwmark - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "ip rule add from 0/0 fwmark \"0x3000/0x3000\" table ovpnc5 prio 9992        # VPN 5 fwmark - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "ip rule add from 0/0 fwmark \"0x1000/0x1000\" table ovpnc1 prio 9993        # VPN 1 fwmark - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "ip rule add from 0/0 fwmark \"0x2000/0x2000\" table ovpnc2 prio 9994        # VPN 2 fwmark - Added by vpnmon-r3" >> /jffs/scripts/nat-start
                  echo "ip rule add from 0/0 fwmark \"0x4000/0x4000\" table ovpnc3 prio 9995        # VPN 3 fwmark - Added by vpnmon-r3" >> /jffs/scripts/nat-start
               fi

              else
                curl --silent --fail --retry 3 --max-time 10 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/nat-start" -o "/jffs/scripts/nat-start" && chmod 755 "/jffs/scripts/nat-start"
              fi

              # Modify or create openvpn-event
              if [ -f /jffs/scripts/openvpn-event ]; then

                if ! grep -q -F "[ "'"${dev:0:4}"'" = 'tun1' ] && vpn_id" /jffs/scripts/openvpn-event; then
                  echo "[ "'"${dev:0:4}"'" = 'tun1' ] && vpn_id=$unboundovervpn &&  [ "'"$script_type"'" = 'route-up' ] && /jffs/addons/unbound/unbound_DNS_via_OVPN.sh \$vpn_id start &" >> /jffs/scripts/openvpn-event
                  echo "[ "'"${dev:0:4}"'" = 'tun1' ] && vpn_id=$unboundovervpn &&  [ "'"$script_type"'" = 'route-pre-down' ] && /jffs/addons/unbound/unbound_DNS_via_OVPN.sh \$vpn_id stop &" >> /jffs/scripts/openvpn-event
                fi

              else
                echo "#!/bin/sh" > /jffs/scripts/openvpn-event
                echo "" >> /jffs/scripts/openvpn-event
                echo "[ "'"${dev:0:4}"'" = 'tun1' ] && vpn_id=$unboundovervpn &&  [ "'"$script_type"'" = 'route-up' ] && /jffs/addons/unbound/unbound_DNS_via_OVPN.sh \$vpn_id start &" >> /jffs/scripts/openvpn-event
                echo "[ "'"${dev:0:4}"'" = 'tun1' ] && vpn_id=$unboundovervpn &&  [ "'"$script_type"'" = 'route-pre-down' ] && /jffs/addons/unbound/unbound_DNS_via_OVPN.sh \$vpn_id stop &" >> /jffs/scripts/openvpn-event
                chmod 755 /jffs/scripts/openvpn-event
              fi

              # Download and create the unbound_DNS_via_OVPN.sh file - many thanks to @Martineau and @Swinson
              if [ ! -f /jffs/addons/unbound/unbound_DNS_via_OVPN.sh ]; then
                curl --silent --fail --retry 3 --max-time 10 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/MartineauUK/Unbound-Asuswrt-Merlin/dev/unbound_DNS_via_OVPN.sh" -o "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh" && chmod 755 "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh"
              fi

              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound-over-VPN was enabled for VPNMON-R3" >> $logfile
              echo -e "${CClear}"
              unboundclient=$unboundovervpn
              saveconfig
              echo "Please reboot your router now if this is your first time or re-enabled Unbound over VPN"
              read -rsp $'Press any key to continue...\n' -n1 key
              continue

            elif [ "$unboundovervpn" = "e" ]; then
              echo -e "${CClear}\n[Exiting]"; sleep 2; break
            fi

          else
            echo -e "${CClear}\n[Exiting]"; sleep 2; break
          fi
        done
      ;;

      5)

        if [ "$unboundclient" -ge 1 ]; then
          echo ""
          echo -e "${CRed}Unbound-over-VPN is currently enabled. If you want to enable Unbound-over-WG, please proceed to 'Disable'"
          echo -e "the Unbound-over-VPN option first, then choose to enable Unbound-over-WG.${CClear}"
          echo ""
          sleep 3
          read -rsp $'Press any key to continue...\n' -n1 key
          continue
        fi

        while true; do
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Unbound DNS Lookups over WG Integration                                               ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate if you would like to enable an integration with Unbound which allows${CClear}"
          echo -e "${InvGreen} ${CClear} you to force any DNS lookups that Unbound would normally handle, but over your WG${CClear}"
          echo -e "${InvGreen} ${CClear} connection, essentially allowing you to appear as your own DNS resolver. DNS resolver${CClear}"
          echo -e "${InvGreen} ${CClear} traffic generated by Unbound is unencrypted as it queries DNS Root Servers by default.${CClear}"
          echo -e "${InvGreen} ${CClear} This integration encrypts your DNS Resolver traffic up to your Public WG IP address,${CClear}"
          echo -e "${InvGreen} ${CClear} after which it goes unencrypted to the DNS Root Servers, preventing any ISP or other${CClear}"
          echo -e "${InvGreen} ${CClear} traffic inspection snooping when sending this across your WAN connection.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} IMPORTANT: This integration will only work with 1 primary WG connection that is${CClear}"
          echo -e "${InvGreen} ${CClear} designated as the connection that will carry DNS resolution traffic. This integration${CClear}"
          echo -e "${InvGreen} ${CClear} will work when multiple WG connections are running, but the other WG connections may${CClear}"
          echo -e "${InvGreen} ${CClear} not be able to utilize the Unbound functionality, and considered standalone. You will${CClear}"
          echo -e "${InvGreen} ${CClear} need to identify one WG Client Slot that will remain on at all times. This integration${CClear}"
          echo -e "${InvGreen} ${CClear} is much more elegant and simple when it compares to the Unbound over VPN integration.${CClear}"
          echo -e "${InvGreen} ${CClear} Should your WG connection go down, browsing/DNS resolution will continue to function${CClear}"
          echo -e "${InvGreen} ${CClear} by traversing directly out over the WAN.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${CRed}WARNING: As of around March 1 2024, the Unbound integration no longer works with the${CClear}"
          echo -e "${InvGreen} ${CClear} ${CRed}NordVPN Service due to possible blocking on their end. This service continues to work${CClear}"
          echo -e "${InvGreen} ${CClear} ${CRed}as advertised with other VPN Providers, like AirVPN. Use at your own risk.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${CGreen}Requirements:"
          echo -e "${InvGreen} ${CClear} ${CGreen}1. Unbound must already be installed and functioning (AMTM)"
          echo -e "${InvGreen} ${CClear} ${CGreen}2. One static WG Slot must be designated for Unbound-over-WG use"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${CGreen}The following will be added/modified:"
          echo -e "${InvGreen} ${CClear} ${CGreen}1. A new virtual br0 interface will be created on 10.99.88.77 (added)"
          echo -e "${InvGreen} ${CClear} ${CGreen}2. A new ip rule will be added to point your WG Slot to this new br0 interface (added)"
          echo -e "${InvGreen} ${CClear} ${CGreen}3. The unbound.conf will have its outgoing-interface modified to 10.99.88.77 (modified)"
          echo -e "${InvGreen} ${CClear} ${CGreen}4. Unbound service will be restarted.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} (Default = 0 / Disabled)${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          if [ $unboundwgclient -eq 0 ]; then
            unboundwgclientexp="Disabled"
          else
            unboundwgclientexp="Enabled, WGC$unboundwgclient"
          fi

          echo -e "${CClear}Current: ${CGreen}$unboundwgclientexp${CClear}"
          echo ""
          read -p "Please enter value (Disabled=0, WG Client=1-5)? (e=Exit): " unboundoverwg

          if [ ! -d "/jffs/addons/unbound" ]; then
            echo ""
            echo -e "${CRed}[Unbound was not detected on this system. Exiting...]${CClear}"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: Unbound was not detected on this system." >> $logfile
            unboundwgclient=0
            saveconfig
            sleep 3
            continue
          fi

          if [ "$unboundoverwg" = "0" ] || [ "$unboundoverwg" = "1" ] || [ "$unboundoverwg" = "2" ] || [ "$unboundoverwg" = "3" ] || [ "$unboundoverwg" = "4" ] || [ "$unboundoverwg" = "5" ] || [ "$unboundoverwg" = "e" ]; then
            if [ "$unboundoverwg" = "0" ]; then

              # Delete all additions made to files to enable Unbound over VPN functionality
              echo ""
              echo -e "${CGreen}[Disabling Unbound over WG]...${CClear}"
              sleep 2

              # ===============================================
              # === Disable Unbound-over-WG Integration     ===
              # === Methodology engineered by @ZebMcKayhan  ===
              # ===============================================

              # Modify unbound.conf file - set major variables
              UNBOUND_CONF="/opt/var/lib/unbound/unbound.conf"
              DISABLED_LINE="#outgoing-interface: 10.0.20.1              # v1.08 Martineau Use VPN tunnel to hide Root server queries from ISP (or force WAN ONLY)"

              # Check if the unbound.conf file exists and is readable.
              if [ ! -r "${UNBOUND_CONF}" ]; then
                echo ""
                echo -e "${CRed}Error: Unbound Configuration file not found or not readable at ${UNBOUND_CONF}${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Unbound Configuration file not found or not readable at ${UNBOUND_CONF}" >> $logfile
                sleep 3
                continue
              fi

              # Create a temp file to move unbound.conf contents into
              TMP_FILE="${UNBOUND_CONF}.$$"

              # Remove outgoing-interface contents and replace with a dummy line
              sed "s/^[[:space:]]*#*[[:space:]]*outgoing-interface:.*/${DISABLED_LINE}/g" "${UNBOUND_CONF}" > "${TMP_FILE}"
              echo ""
              echo -e "${CGreen}[Disabled 'outgoing-interface' and set back to default]...${CClear}"
              sleep 1

              # Ensure the temporary file was created and is not empty before overwriting the original
              if [ ! -s "${TMP_FILE}" ]; then
                echo -e "${CRed}Error: Failed to modify configuration. The temporary file is empty or was not created.${CClear}"
                echo -e "${CRed}No changes have been made to ${UNBOUND_CONF}.${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Failed to modify configuration. The temporary file is empty or was not created." >> $logfile
                sleep 3
                continue
              fi

              # Move the temp file into the unbound.conf file
              mv "${TMP_FILE}" "${UNBOUND_CONF}" >/dev/null 2>&1
              echo ""
              echo -e "${CGreen}[Modified unbound.conf file back to defaults]...${CClear}"
              sleep 1

              # Restart unbound service
              if [ -f "/jffs/addons/unbound/unbound_manager.sh" ]; then
                unbound_manager restart >/dev/null 2>&1
                RESTART_STATUS=$?
                if [ ${RESTART_STATUS} -eq 0 ]; then
                  echo ""
                  echo -e "${CGreen}[Unbound service restarted successfully]...${CClear}"
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound service restarted successfully" >> $logfile
                  sleep 1
                else
                  echo ""
                  echo -e "${CRed}[Warning: 'unbound_manager restart' command failed with status ${RESTART_STATUS}]...${CClear}"
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: 'unbound_manager restart' command failed with status ${RESTART_STATUS}" >> $logfile
                  sleep 3
                fi
              else
                echo ""
                echo -e "${CRed}[Warning: 'unbound_manager.sh' script not found. Could not restart service]...${CClear}"
                echo -e "${CRed}[Please restart the unbound service manually]...${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: 'unbound_manager.sh' script not found. Could not restart service" >> $logfile
                sleep 3
              fi

              # Remove the IP rule from VPN Director
              ip rule del prio 11 >/dev/null 2>&1
              echo ""
              echo -e "${CGreen}[Removed IP rule for virtual br0 interface at 10.99.88.77]...${CClear}"
              sleep 1

              # Remove added virtual br0 interface
              ifconfig br0:UnboundWG down >/dev/null 2>&1
              echo ""
              echo -e "${CGreen}[Removed virtual br0 interface at 10.99.88.77]...${CClear}"
              sleep 1

              # Remove Unbound failsafe in init-start
              if [ -f /jffs/scripts/init-start ]; then
                sed -i -e '/vpnmon-r3/d' /jffs/scripts/init-start
              fi
              echo ""
              echo -e "${CGreen}[Unbound failsafe removed from init-start file]...${CClear}"
              sleep 1

              # Remove Unbound failsafe in nat-start
              if [ -f /jffs/scripts/nat-start ]; then
                sed -i -e '/vpnmon-r3/d' /jffs/scripts/nat-start
              fi
              echo ""
              echo -e "${CGreen}[Unbound failsafe removed from nat-start file]...${CClear}"
              sleep 1

              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound-over-WG was removed from VPNMON-R3" >> $logfile
              unboundwgclient=0
              saveconfig

              echo ""
              echo "Please consider rebooting your router now after major Unbound and system file changes."
              echo ""
              sleep 3
              read -rsp $'Press any key to continue...\n' -n1 key
              continue

            elif [ "$unboundoverwg" = "1" ] || [ "$unboundoverwg" = "2" ] || [ "$unboundoverwg" = "3" ] || [ "$unboundoverwg" = "4" ] || [ "$unboundoverwg" = "5" ]; then

              if [ "$unboundoverwg" = "$unboundwgclient" ]; then
                echo -e "${CClear}\n[Unbound over WGC$unboundoverwg Already Active]"; sleep 3; break
              fi

              if [ "$unboundoverwg" = "1" ] || [ "$unboundoverwg" = "2" ] || [ "$unboundoverwg" = "3" ] || [ "$unboundoverwg" = "4" ] || [ "$unboundoverwg" = "5" ] && [ $unboundwgclient -ge 1 ]; then
                echo ""
                echo -e "${CRed}When changing a WG Client Slot (from WGC #$unboundwgclient to WGC #$unboundoverwg), please proceed to 'Disable'"
                echo -e "first (option 0), then choose a new WG Slot.${CClear}"
                echo ""
                sleep 3
                read -rsp $'Press any key to continue...\n' -n1 key
                continue
              fi

              # ===============================================
              # === Create Unbound-over-WG Integration      ===
              # === Methodology engineered by @ZebMcKayhan  ===
              # ===============================================

              echo ""
              echo -e "${CGreen}[Enabling Unbound over WG]...${CClear}"
              sleep 2

              # Create new virtual br0 interface
              ifconfig br0:UnboundWG 10.99.88.77 netmask 255.255.255.255 up >/dev/null 2>&1
              echo ""
              echo -e "${CGreen}[Added virtual br0 interface at 10.99.88.77]...${CClear}"
              sleep 1

              # Point WG slot to new br0 interface for VPN Director
              ip rule add from 10.99.88.77 lookup wgc$unboundoverwg prio 11 >/dev/null 2>&1
              echo ""
              echo -e "${CGreen}[Pointed wgc$unboundoverwg to virtual br0 interface at 10.99.88.77]...${CClear}"
              sleep 1

              # Modify unbound.conf file - set major variables
              UNBOUND_CONF="/opt/var/lib/unbound/unbound.conf"
              ENABLED_IP="10.99.88.77"
              COMMENT="# v1.08 Martineau Use VPN tunnel to hide Root server queries from ISP (or force WAN ONLY)"

              # Check if the unbound.conf file exists and is readable.
              if [ ! -r "${UNBOUND_CONF}" ]; then
                echo ""
                echo -e "${CRed}Error: Unbound Configuration file not found or not readable at ${UNBOUND_CONF}${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Unbound Configuration file not found or not readable at ${UNBOUND_CONF}" >> $logfile
                sleep 3
                continue
              fi

              # Create a temp file to move unbound.conf contents into
              TMP_FILE="${UNBOUND_CONF}.$$"

              # Create new outgoing-interface contents
              ENABLED_LINE="outgoing-interface: ${ENABLED_IP}             ${COMMENT}"
              sed "s/^[[:space:]]*#*[[:space:]]*outgoing-interface:.*/${ENABLED_LINE}/g" "${UNBOUND_CONF}" > "${TMP_FILE}"

              # Ensure the temporary file was created and is not empty before overwriting the original
              if [ ! -s "${TMP_FILE}" ]; then
                echo -e "${CRed}Error: Failed to modify configuration. The temporary file is empty or was not created.${CClear}"
                echo -e "${CRed}No changes have been made to ${UNBOUND_CONF}.${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Failed to modify configuration. The temporary file is empty or was not created." >> $logfile
                sleep 3
                continue
              fi

              # Move the temp file into the unbound.conf file
              mv "${TMP_FILE}" "${UNBOUND_CONF}" >/dev/null 2>&1
              echo ""
              echo -e "${CGreen}[Modified unbound.conf file 'outgoing-interface: 10.99.88.77']...${CClear}"
              sleep 1

              # Restart unbound service
              if [ -f "/jffs/addons/unbound/unbound_manager.sh" ]; then
                unbound_manager restart >/dev/null 2>&1
                RESTART_STATUS=$?
                if [ ${RESTART_STATUS} -eq 0 ]; then
                  echo ""
                  echo -e "${CGreen}[Unbound service restarted successfully]...${CClear}"
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound service restarted successfully" >> $logfile
                  sleep 1
                else
                  echo ""
                  echo -e "${CRed}[Warning: 'unbound_manager restart' command failed with status ${RESTART_STATUS}]...${CClear}"
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: 'unbound_manager restart' command failed with status ${RESTART_STATUS}" >> $logfile
                  sleep 3
                fi
              else
                echo ""
                echo -e "${CRed}[Warning: 'unbound_manager.sh' script not found. Could not restart service]...${CClear}"
                echo -e "${CRed}[Please restart the unbound service manually]...${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: 'unbound_manager.sh' script not found. Could not restart service" >> $logfile
                sleep 3
              fi

              echo ""
              echo -e "${CGreen}[Adding Unbound Failsafe... Modifying init-start file]...${CClear}"
              sleep 1

              # Modify or create init-start to ensure survivability after a router reboot
              if [ -f /jffs/scripts/init-start ]; then

                if ! grep -q -F "sh /jffs/scripts/vpnmon-r3.sh -uowginitstart" /jffs/scripts/init-start; then
                  echo "sh /jffs/scripts/vpnmon-r3.sh -uowginitstart # Added by vpnmon-r3" >> /jffs/scripts/init-start
                fi

              else
                echo "#!/bin/sh" > /jffs/scripts/init-start
                echo "" >> /jffs/scripts/init-start
                echo "sh /jffs/scripts/vpnmon-r3.sh -uowginitstart # Added by vpnmon-r3" >> /jffs/scripts/init-start
                chmod 755 /jffs/scripts/init-start
              fi

              echo ""
              echo -e "${CGreen}[Adding Unbound Failsafe... Modifying nat-start file]...${CClear}"
              sleep 1

              # Modify or create nat-start to ensure survivability after a router reboot
              if [ -f /jffs/scripts/nat-start ]; then

                if ! grep -q -F "sh /jffs/scripts/vpnmon-r3.sh -uowgnatstart" /jffs/scripts/nat-start; then
                  echo "sh /jffs/scripts/vpnmon-r3.sh -uowgnatstart # Added by vpnmon-r3" >> /jffs/scripts/nat-start
                fi

              else
                echo "#!/bin/sh" > /jffs/scripts/nat-start
                echo "" >> /jffs/scripts/nat-start
                echo "sh /jffs/scripts/vpnmon-r3.sh -uowgnatstart # Added by vpnmon-r3" >> /jffs/scripts/nat-start
                chmod 755 /jffs/scripts/nat-start
              fi

              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound-over-WG was enabled for VPNMON-R3" >> $logfile
              echo -e "${CClear}"
              unboundwgclient=$unboundoverwg
              saveconfig

              echo ""
              echo "Please consider rebooting your router now if this is your first time or have re-enabled Unbound-over-WG"
              echo ""
              sleep 3
              read -rsp $'Press any key to continue...\n' -n1 key
              continue

            elif [ "$unboundoverwg" = "e" ]; then
              echo -e "${CClear}\n[Exiting]"; sleep 2; break
            fi

          else
            echo -e "${CClear}\n[Exiting]"; sleep 2; break
          fi
        done
      ;;

      6)
        if [ "$unboundclient" != "0" ] || [ "$unboundwgclient" != "0" ]; then
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Show Expanded Unbound IP Information                                                  ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate below if you would like to show your full Unbound DNS Resolver IP on-${CClear}"
          echo -e "${InvGreen} ${CClear} screen, or just an abbreviated color-coded indicator. Showing a full IP may in some${CClear}"
          echo -e "${InvGreen} ${CClear} cases help with troubleshooting.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Use 0 to Disable, 1 to Enable. (Default = 0)"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo
          echo -e "${CClear}Current: ${CGreen}$unboundshowipdisp${CClear}" ; echo
          read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newunboundshowip
          if [ "$newunboundshowip" = "0" ]
          then
              unboundshowip=0
              unboundshowipdisp="Disabled"
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Expanded Unbound IP Information Disabled" >> $logfile
              saveconfig
          elif [ "$newunboundshowip" = "1" ]
          then
              unboundshowip=1
              unboundshowipdisp="Enabled"
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Expanded Unbound IP Information Enabled" >> $logfile
              saveconfig
          elif [ "$newunboundshowip" = "e" ]
          then
              echo -e "\n[Exiting]"; sleep 2
          else
              previousValue="$unboundshowip"
              unboundshowip="${unboundshowip:=0}"
              unboundshowipdisp="$([ "$unboundshowip" = "0" ] && echo "Disabled" || echo "Enabled")"
              [ "$unboundshowip" != "$previousValue" ] && \
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Expanded Unbound IP Information Disabled" >> $logfile
              saveconfig
          fi
        fi
      ;;

      7)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Refresh Custom Server Lists on -RESET Switch                                          ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below if you would like to automatically refresh your custom Server${CClear}"
        echo -e "${InvGreen} ${CClear} Lists specified under the Edit/Run Server List Automation menu. This function will${CClear}"
        echo -e "${InvGreen} ${CClear} run any defined CURL+JQ statements you have configured and save them back to your${CClear}"
        echo -e "${InvGreen} ${CClear} Client Slot Server List files that will be used for VPN connections.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 0 to Disable, 1 to Enable. (Default = 0)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$refreshserverlistsdisp${CClear}" ; echo
        read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newRefreshServerList
        if [ "$newRefreshServerList" = "0" ]
        then
            refreshserverlists=0
            refreshserverlistsdisp="Disabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom Server Lists Disabled on -RESET Switch" >> $logfile
            saveconfig
        elif [ "$newRefreshServerList" = "1" ]
        then
            refreshserverlists=1
            refreshserverlistsdisp="Enabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom Server Lists Enabled on -RESET Switch" >> $logfile
            saveconfig
        elif [ "$newRefreshServerList" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            previousValue="$refreshserverlists"
            refreshserverlists="${refreshserverlists:=0}"
            refreshserverlistsdisp="$([ "$refreshserverlists" = "0" ] && echo "Disabled" || echo "Enabled")"
            [ "$refreshserverlists" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom Server Lists $refreshserverlistsdisp on -RESET Switch" >> $logfile
            saveconfig
        fi
      ;;

      8)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Provide WAN/Dual WAN Monitoring Functionality                                         ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below if you would like to monitor your WAN/Dual WAN connection for${CClear}"
        echo -e "${InvGreen} ${CClear} connectivity issues that may impact your VPN connection. This functionality will${CClear}"
        echo -e "${InvGreen} ${CClear} determine if your WAN connection is viable, and upon determining that the WAN is${CClear}"
        echo -e "${InvGreen} ${CClear} down, VPNMON-R3 will kill all VPN connections and continue testing for a valid WAN${CClear}"
        echo -e "${InvGreen} ${CClear} connection until it can restore your VPN connections.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 0 to Disable, 1 to Enable. (Default = 0)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$monitorwandisp${CClear}" ; echo
        read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newMonitorWAN
        if [ "$newMonitorWAN" = "0" ]
        then
            monitorwan=0
            monitorwandisp="Disabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WAN Monitoring Disabled" >> $logfile
            saveconfig
        elif [ "$newMonitorWAN" = "1" ]
        then
            monitorwan=1
            monitorwandisp="Enabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WAN Monitoring Enabled" >> $logfile
            saveconfig
        elif [ "$newMonitorWAN" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            previousValue="$monitorwan"
            monitorwan="${monitorwan:=0}"
            monitorwandisp="$([ "$monitorwan" = "0" ] && echo "Disabled" || echo "Enabled")"
            [ "$monitorwan" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WAN Monitoring $monitorwandisp" >> $logfile
            saveconfig
        fi
      ;;

      9)
        while true
        do
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Enable/Disable VPN/WG Slot Monitoring and Display                                     ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate whether you want to enable or disable VPN/WG Slots from being${CClear}"
          echo -e "${InvGreen} ${CClear} monitored and shown on the main VPNMON-R3 UI. This setting is meant for those${CClear}"
          echo -e "${InvGreen} ${CClear} who are only running VPN or only WG on their router, and do not want to display${CClear}"
          echo -e "${InvGreen} ${CClear} one or the other to only show relevant info.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to enable/disable monitoring for each.${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"

          if [ "$useovpn" = "1" ]; then useovpnDisp="${CGreen}Y${CCyan}"; else useovpn=0; useovpnDisp="${CRed}N${CCyan}"; fi
          if [ "$usewg" = "1" ]; then usewgDisp="${CGreen}Y${CCyan}"; else usewg=0; usewgDisp="${CRed}N${CCyan}"; fi
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}  OpenVPN${CClear} ${CGreen}(1) -${CClear} $useovpnDisp${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}Wireguard${CClear} ${CGreen}(2) -${CClear} $usewgDisp${CClear}"
          echo ""
          read -p "Please select? (1-2, e=Exit): " SelectSlot
            case $SelectSlot in
              1)
                 if [ "$unboundclient" = "0" ]; then
                   if [ "$useovpn" = "0" ]; then
                    useovpn=1
                    useovpnDisp="${CGreen}Y${CCyan}"
                   elif [ "$useovpn" = "1" ]; then
                    useovpn=0; useovpnDisp="${CRed}N${CCyan}"
                   fi
                 else
                   echo -e "${CClear}\n[Unable to disable VPN. Unbound Active on Slot VPN$unboundclient]"; sleep 3
                 fi;;
              2)
                 if [ "$usewg" = "0" ]; then
                  usewg=1
                  usewgDisp="${CGreen}Y${CCyan}"
                 elif [ "$usewg" = "1" ]; then
                  usewg=0
                  usewgDisp="${CRed}N${CCyan}"
                 fi;;
              [Ee])
                 saveconfig
                 echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN/WG Client Slot Monitoring/Display configuration saved" >> $logfile
                 timer="$timerloop"
                 break;;
            esac
        done

      ;;

      10)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Whitelist VPN Server IP Lists in Skynet                                               ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below if you would like to whitelist your VPN Server IP lists in${CClear}"
        echo -e "${InvGreen} ${CClear} the Skynet Firewall. This provides for better stability in connecting to your VPN${CClear}"
        echo -e "${InvGreen} ${CClear} provider, as there have been occasions where the Skynet blacklist will prevent${CClear}"
        echo -e "${InvGreen} ${CClear} connections to your VPN Servers. This could cause a disruption in being able to${CClear}"
        echo -e "${InvGreen} ${CClear} maintain a stable VPN connection. Note: Skynet must already be installed and${CClear}"
        echo -e "${InvGreen} ${CClear} operational for this functionality to work.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 0 to Disable, 1 to Enable. (Default = 0)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$updateskynetdisp${CClear}" ; echo
        read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newUpdateSkyNet
        if [ "$newUpdateSkyNet" = "1" ]
        then
            updateskynet=1
            updateskynetdisp="Enabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Server IP Skynet Whitelisting Enabled" >> $logfile
            saveconfig
        elif [ "$newUpdateSkyNet" = "0" ]
        then
            updateskynet=0
            updateskynetdisp="Disabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Server IP Skynet Whitelisting Disabled" >> $logfile
            saveconfig
        elif [ "$newUpdateSkyNet" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            previousValue="$updateskynet"
            updateskynet="${updateskynet:=0}"
            updateskynetdisp="$([ "$updateskynet" = "0" ] && echo "Disabled" || echo "Enabled")"
            [ "$updateskynet" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Server IP Skynet Whitelisting $updateskynetdisp" >> $logfile
            saveconfig
        fi
      ;;

      [Ee]) echo -e "${CClear}\n[Exiting]"; sleep 2; timer="$timerloop"; break ;;

      11)
        amtmevents
        source "$config"
      ;;

      12)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Reset spdMerlin Interfaces on VPN Reset                                               ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below if you would like to reset your spdMerlin Interfaces each${CClear}"
        echo -e "${InvGreen} ${CClear} time VPNMON-R3 resets. This functionality will allow VPNMON-R3 to update spdMerlin${CClear}"
        echo -e "${InvGreen} ${CClear} whenever a VPN reset occurs. SpdMerlin will then know which interfaces are active${CClear}"
        echo -e "${InvGreen} ${CClear} in order to run manual or automated speedtests from.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 0 to Disable, 1 to Enable. (Default = 0)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$rstspdmerlindisp${CClear}" ; echo
        read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newrstspdmerlin
        if [ "$newrstspdmerlin" = "0" ]
        then
            rstspdmerlin=0
            rstspdmerlindisp="Disabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: spdMerlin Interface Reset Disabled" >> $logfile
            saveconfig
        elif [ "$newrstspdmerlin" = "1" ]
        then
            rstspdmerlin=1
            rstspdmerlindisp="Enabled"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: spdMerlin Interface Reset Enabled" >> $logfile
            saveconfig
        elif [ "$newrstspdmerlin" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            previousValue="$rstspdmerlin"
            rstspdmerlin="${rstspdmerlin:=0}"
            rstspdmerlindisp="$([ "$rstspdmerlin" = "0" ] && echo "Disabled" || echo "Enabled")"
            [ "$rstspdmerlin" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: spdMerlin Interface Reset $monitorwandisp" >> $logfile
            saveconfig
        fi
      ;;

      13)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Server List Item Selection Method                                                     ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below if you would like to use a Random or Sequential method to pick${CClear}"
        echo -e "${InvGreen} ${CClear} your next available Server List item to populate your VPN/WG slots. When choosing${CClear}"
        echo -e "${InvGreen} ${CClear} 'Sequential', please know that this method will use a Round-Robin style method, and${CClear}"
        echo -e "${InvGreen} ${CClear} will start at the beginning of your list again after it has used the last entry in${CClear}"
        echo -e "${InvGreen} ${CClear} your list. The 'Sequential' method is a preferred method to use for those using${CClear}"
        echo -e "${InvGreen} ${CClear} shorter lists of servers, as the chances of selecting the same server is much greater${CClear}"
        echo -e "${InvGreen} ${CClear} when using a 'Random' method against these short lists.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = 0 - Random)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$selectionmethoddisp${CClear}" ; echo
        read -p "Please Choose? (Random = 0, Sequential = 1, e=Exit): " newselectionmethod
        if [ "$newselectionmethod" = "0" ]
        then
            selectionmethod=0
            newselectionmethoddisp="Random"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Server List Item Selection Method set to Random" >> $logfile
            saveconfig
        elif [ "$newselectionmethod" = "1" ]
        then
            selectionmethod=1
            newselectionmethoddisp="Sequential"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Server List Item Selection Method set to Sequential" >> $logfile
            saveconfig
        elif [ "$newselectionmethod" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            previousValue="$selectionmethod"
            selectionmethod="${selectionmethod:=0}"
            selectionmethoddisp="$([ "$selectionmethod" = "0" ] && echo "Random" || echo "Sequential")"
            [ "$selectionmethod" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Server List Item Selection Method set to $selectionmethoddisp" >> $logfile
            saveconfig
        fi
      ;;

      14)
        while true
        do
          if [ "$bwdisp" = "1" ]; then bwdispval="Mbps"; else bwdispval="MB"; fi
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Connection Throughput Threshold Selections                                            ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Please indicate below how you would like to configure the visual representation of${CClear}"
          echo -e "${InvGreen} ${CClear} the Connection Throughput that are displayed in the main UI for each active OVPN/WG${CClear}"
          echo -e "${InvGreen} ${CClear} Connection. This is very dependent on your own preferences and the total amount of${CClear}"
          echo -e "${InvGreen} ${CClear} bandwidth your have at your disposal. These ranges represent the different colors${CClear}"
          echo -e "${InvGreen} ${CClear} ${CGreen}Green${CClear} / ${CYellow}Yellow${CClear} / ${CRed}Red ${CClear} to provide visual indicators of the current speeds your${CClear}"
          echo -e "${InvGreen} ${CClear} connections are experiencing at that moment. You are able to choose different sets${CClear}"
          echo -e "${InvGreen} ${CClear} of RX/TX thresholds for those using asymmetric internet connections.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to modify the different thresholds.${CClear}"
          echo -e "${InvGreen} ${CClear} RX Defaults: 0->100 / 100->250 / 250->Max -- TX Defaults: 0->15 / 15->25 / 25->Max${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${InvDkGray}${CWhite} RX (Receive) Thresholds                                                               ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CClear} ${InvGreen}${CWhite}  Low Utilization ${CClear} - 0$bwdispval ---> ${CGreen}(1) ${lowutilspd}$bwdispval${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CClear} ${InvYellow}${CBlack}  Med Utilization ${CClear} - ${lowutilspd}$bwdispval ---> ${CGreen}(2) ${medutilspd}$bwdispval${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CClear} ${InvRed}${CWhite} High Utilization ${CClear} - ${medutilspd}$bwdispval ---> Max Limit${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${InvDkGray}${CWhite} TX (Transmit) Thresholds                                                              ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CClear} ${InvGreen}${CWhite}  Low Utilization ${CClear} - 0$bwdispval ---> ${CGreen}(3) ${lowutilspdup}$bwdispval${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CClear} ${InvYellow}${CBlack}  Med Utilization ${CClear} - ${lowutilspdup}$bwdispval ---> ${CGreen}(4) ${medutilspdup}$bwdispval${CClear}"
          echo -e "${InvGreen} ${CClear} ${InvDkGray}${CClear} ${InvRed}${CWhite} High Utilization ${CClear} - ${medutilspdup}$bwdispval ---> Max Limit${CClear}"
          echo ""
          read -p "Please select? (1-4, e=Exit): " SelectSlot
            case $SelectSlot in
              1)
                 echo ""
                 read -p "Please enter the upper 'Low RX Utilization' range (in $bwdispval)? (Default = 100): " lowutilspdchoice
                 if [ "$lowutilspdchoice" -le 0 ] || [ "$lowutilspdchoice" -ge "$medutilspd" ]
                  then
                    echo ""; echo -e "${CRed}ERROR: Your upper 'Low RX Utilization' range must be greater than 0 and less than $medutilspd.${CClear}"; echo ""
                    sleep 3
                    continue
                  elif [ -z "$lowutilspdchoice" ]
                    then
                      lowutilspd=100
                      continue
                  else
                    lowutilspd=$lowutilspdchoice
                    continue
                 fi;;
              2)
                 echo ""
                 read -p "Please enter the upper 'Med RX Utilization' range (in $bwdispval)? (Default = 250): " medutilspdchoice
                 if [ "$medutilspdchoice" -le "$lowutilspd" ]
                  then
                    echo ""; echo -e "${CRed}ERROR: Your upper 'Med RX Utilization' range must be greater than $lowutilspd.${CClear}"; echo ""
                    sleep 3
                    continue
                  elif [ -z "$medutilspdchoice" ]
                    then
                      medutilspd=250
                      continue
                  else
                    medutilspd=$medutilspdchoice
                    continue
                 fi;;
              3)
                 echo ""
                 read -p "Please enter the upper 'Low TX Utilization' range (in $bwdispval)? (Default = 15): " lowutilspdupchoice
                 if [ "$lowutilspdupchoice" -le 0 ] || [ "$lowutilspdupchoice" -ge "$medutilspdup" ]
                  then
                    echo ""; echo -e "${CRed}ERROR: Your upper 'Low TX Utilization' range must be greater than 0 and less than $medutilspdup.${CClear}"; echo ""
                    sleep 3
                    continue
                  elif [ -z "$lowutilspdupchoice" ]
                    then
                      lowutilspdup=15
                      continue
                  else
                    lowutilspdup=$lowutilspdupchoice
                    continue
                 fi;;
              4)
                 echo ""
                 read -p "Please enter the upper 'Med TX Utilization' range (in $bwdispval)? (Default = 25): " medutilspdupchoice
                 if [ "$medutilspdupchoice" -le "$lowutilspdup" ]
                  then
                    echo ""; echo -e "${CRed}ERROR: Your upper 'Med TX Utilization' range must be greater than $lowutilspdup.${CClear}"; echo ""
                    sleep 3
                    continue
                  elif [ -z "$medutilspdupchoice" ]
                    then
                      medutilspdup=25
                      continue
                  else
                    medutilspdup=$medutilspdupchoice
                    continue
                 fi;;
              [Ee])
                 saveconfig
                 echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Connection Speed Threshold Selections Set -- RX: 0->$lowutilspd->$medutilspd->Max | TX: 0->$lowutilspdup->$medutilspdup->Max" >> $logfile
                 timer="$timerloop"
                 break;;
            esac
        done
      ;;

      15)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Connection Throughput Display Method                                                  ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below what kind of information you would like to display in the${CClear}"
        echo -e "${InvGreen} ${CClear} Connection Throughput field within the main VPNMON-R3 UI? You have the choice${CClear}"
        echo -e "${InvGreen} ${CClear} between displaying Average Throughput in Mbps (average speed across tunnels), ${CClear}"
        echo -e "${InvGreen} ${CClear} or Total Throughput in MB (total amount of data sent/received across tunnels),${CClear}"
        echo -e "${InvGreen} ${CClear} which is calculated each time your timer restarts.${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Use 1 for Average Throughput (in Mbps), 2 for Total Throughput (in MB). (Default = 1)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$throughputmethoddisp${CClear}" ; echo
        read -p "Please Choose? (Avg in Mbps = 1, Ttl in MB = 2, e=Exit): " newthroughputmethod
        if [ "$newthroughputmethod" = "1" ]
        then
            bwdisp=1
            throughputmethoddisp="Average Throughput (in Mbps)"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Connection Throughput Display Method set to: Average Throughput (in Mbps)" >> $logfile
            saveconfig
        elif [ "$newthroughputmethod" = "2" ]
        then
            bwdisp=2
            throughputmethoddisp="Total Throughput (in MB)"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Connection Throughput Display Method set to: Total Throughput (in MB)" >> $logfile
            saveconfig
        elif [ "$newthroughputmethod" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        else
            bwdisp=1
            throughputmethoddisp="Average Throughput (in Mbps)"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Connection Throughput Display Method set to: Average Throughput (in Mbps)" >> $logfile
            saveconfig
        fi
      ;;

      16)
        if [ "$monitorwan" -eq 1 ]; then
          clear
          while true
          do
            clear
            echo -e "${InvGreen} ${InvDkGray}${CWhite} WAN Recovery Timer Configuration                                                      ${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} Please indicate how long the various WAN Recovery timers should last during the${CClear}"
            echo -e "${InvGreen} ${CClear} different states as the WAN tries to recover, or goes out completely. Depending${CClear}"
            echo -e "${InvGreen} ${CClear} on what timer values you choose will have impact on how long your WAN takes to${CClear}"
            echo -e "${InvGreen} ${CClear} recover.${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} ${CYellow}Recovery timer${CClear}: The length of time between tries to determine if your router is${CClear}"
            echo -e "${InvGreen} ${CClear} able to ping the IP address of your choosing and recover before declaring a WAN${CClear}"
            echo -e "${InvGreen} ${CClear} DOWN situation. (Default = 10 sec)${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} ${CYellow}WAN DOWN Timer${CClear}: The length of time between tries while the WAN is DOWN, where${CClear}"
            echo -e "${InvGreen} ${CClear} VPNMON-R3 tries to determine if the WAN is available again. (Default = 60 sec)${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} ${CYellow}Reconnect Timer${CClear}: The length of time from when the WAN is declared back up while${CClear}"
            echo -e "${InvGreen} ${CClear} giving the router some time to stabilize before it restarts VPN/WG tunnels. You don't${CClear}"
            echo -e "${InvGreen} ${CClear} want your router reconnecting tunnels while the router is bouncing up and down.${CClear}"
            echo -e "${InvGreen} ${CClear} (Default = 300 sec).${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} Current:${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} Recovery Timer  ${CGreen}(1): $recoverytimer sec${CClear}"
            echo -e "${InvGreen} ${CClear} WAN DOWN Timer  ${CGreen}(2): $wandowntimer sec ${CClear}"
            echo -e "${InvGreen} ${CClear} Reconnect Timer ${CGreen}(3): $reconnecttimer sec ${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo
            read -p "Please choose a Timer [1-3] and enter new Timer value in seconds (e=Exit): " newTimerChoice
            case $newTimerChoice in
                1) echo ""
                   read -p "Enter new Recovery Timer value in seconds between [10-999] (default=10, e=Exit): " newRecoveryTimerChoice
                      if [ -z "$newRecoveryTimerChoice" ] || echo "$newRecoveryTimerChoice" | grep -qE "^(e|E)$"
                      then
                          if echo "$recoverytimer" | grep -qE "^([1-9][0-9]{0,2})$" && \
                             [ "$recoverytimer" -ge 10 ] && [ "$recoverytimer" -le 999 ]
                          then
                              printf "\n${CClear}[Exiting]\n"
                              sleep 1 ; break
                          else
                              printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
                              sleep 3
                          fi
                      elif echo "$newRecoveryTimerChoice" | grep -qE "^([1-9][0-9]{0,2})$" && \
                           [ "$newRecoveryTimerChoice" -ge 10 ] && [ "$newRecoveryTimerChoice" -le 999 ]
                      then
                          recoverytimer="$newRecoveryTimerChoice"
                          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Recovery Timer ($recoverytimer sec) configuration saved" >> $logfile
                          saveconfig
                          printf "\n${CClear}[OK]\n"
                          sleep 1
                      else
                          printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
                          sleep 3
                      fi
                ;;

                2) echo ""
                   read -p "Enter new WAN-DOWN Timer value in seconds between [10-999] (default=60, e=Exit): " newWANDOWNTimerChoice
                      if [ -z "$newWANDOWNTimerChoice" ] || echo "$newWANDOWNTimerChoice" | grep -qE "^(e|E)$"
                      then
                          if echo "$wandowntimer" | grep -qE "^([1-9][0-9]{0,2})$" && \
                             [ "$wandowntimer" -ge 10 ] && [ "$wandowntimer" -le 999 ]
                          then
                              printf "\n${CClear}[Exiting]\n"
                              sleep 1 ; break
                          else
                              printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
                              sleep 3
                          fi
                      elif echo "$newWANDOWNTimerChoice" | grep -qE "^([1-9][0-9]{0,2})$" && \
                           [ "$newWANDOWNTimerChoice" -ge 10 ] && [ "$newWANDOWNTimerChoice" -le 999 ]
                      then
                          wandowntimer="$newWANDOWNTimerChoice"
                          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New WAN-DOWN Timer ($recoverytimer sec) configuration saved" >> $logfile
                          saveconfig
                          printf "\n${CClear}[OK]\n"
                          sleep 1
                      else
                          printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
                          sleep 3
                      fi
                ;;

                3) echo ""
                   read -p "Enter new Reconnect Timer value in seconds between [10-999] (default=300, e=Exit): " newReconnectTimerChoice
                      if [ -z "$newReconnectTimerChoice" ] || echo "$newReconnectTimerChoice" | grep -qE "^(e|E)$"
                      then
                          if echo "$reconnecttimer" | grep -qE "^([1-9][0-9]{0,2})$" && \
                             [ "$reconnecttimer" -ge 10 ] && [ "$reconnecttimer" -le 999 ]
                          then
                              printf "\n${CClear}[Exiting]\n"
                              sleep 1 ; break
                          else
                              printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
                              sleep 3
                          fi
                      elif echo "$newReconnectTimerChoice" | grep -qE "^([1-9][0-9]{0,2})$" && \
                           [ "$newReconnectTimerChoice" -ge 10 ] && [ "$newReconnectTimerChoice" -le 999 ]
                      then
                          reconnecttimer="$newReconnectTimerChoice"
                          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Reconnect Timer ($recoverytimer sec) configuration saved" >> $logfile
                          saveconfig
                          printf "\n${CClear}[OK]\n"
                          sleep 1
                      else
                          printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
                          sleep 3
                      fi
                ;;

                [Ee]) printf "\n${CClear}[Exiting]\n"
                      sleep 1 ; break
            esac
          done
        fi
      ;;

      17)
        dvpn_setup
      ;;

    esac
done
}

# -------------------------------------------------------------------------------------------------------------------------
# uowginitstart is a function that initializes the virtual br0 interface when called from init-start

uowginitstart()
{

 if [ -f "$config" ]
   then
    source "$config"

    # Remove added virtual br0 interface if it already exists
    ifconfig br0:UnboundWG down >/dev/null 2>&1

    # Addvirtual br0 interface
    ifconfig br0:UnboundWG 10.99.88.77 netmask 255.255.255.255 up >/dev/null 2>&1
 fi

}

# -------------------------------------------------------------------------------------------------------------------------
# uowgnatstart is a function that ties the virtual br0 interface to the assigned wgc slot

uowgnatstart()
{

 if [ -f "$config" ]
   then
    source "$config"

    # Remove ip rule if it already exists
    ip rule del prio 11 >/dev/null 2>&1

    # Add ip rule to tie br0 interface with assigned wgc slot
    ip rule add from 10.99.88.77 lookup wgc$unboundwgclient prio 11 >/dev/null 2>&1
 fi

}

# -------------------------------------------------------------------------------------------------------------------------
# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...

vupdate()
{

updatecheck # Check for the latest version from source repository
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 Update Utility                                                              ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This utility allows you to check, download and install updates"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Current Version: ${CGreen}$version${CClear}"
  echo -e "Updated Version: ${CGreen}$DLversion${CClear}"
  echo ""
  if [ "$version" = "$DLversion" ]
    then
      echo -e "You are on the latest version! Would you like to download anyways? This will overwrite${CClear}"
      echo -e "your local copy with the current build.${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo -e "\nDownloading VPNMON-R3 ${CGreen}v$DLversion${CClear}"
        curl --silent --fail --retry 3 --max-time 10 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Successfully downloaded and installed VPNMON-R3 v$DLversion" >> $logfile
        echo ""
        read -rsp $'Press any key to restart VPNMON-R3...\n' -n1 key
        exec /jffs/scripts/vpnmon-r3.sh -setup
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "Score! There is a new version out there! Would you like to update?${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo -e "\nDownloading VPNMON-R3 ${CGreen}v$DLversion${CClear}"
        curl --silent --fail --retry 3 --max-time 10 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Successfully downloaded and installed VPNMON-R3 v$DLversion" >> $logfile
        echo ""
        read -rsp $'Press any key to restart VPNMON-R3...\n' -n1 key
        exec /jffs/scripts/vpnmon-r3.sh -setup
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
  fi
done

}

# -------------------------------------------------------------------------------------------------------------------------
# updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed

updatecheck()
{

  # Download the latest version file from the source repository
  curl --silent --fail --retry 3 --max-time 10 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/version.txt" -o "/jffs/addons/vpnmon-r3.d/version.txt"

  if [ -f $dlverpath ]
    then
      # Read in its contents for the current version file
      DLversion=$(cat $dlverpath)

      # Compare the new version with the old version and log it
      if [ "$beta" = "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLversion" != "$version" ]; then
        DLversionPF=$(printf "%-8s" $DLversion)
        versionPF=$(printf "%-8s" $version)
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$versionPF -> v$DLversionPF                                                                                       ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: A new update (v$DLversion) is available to download" >> $logfile
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# vuninstall is a function that uninstalls and removes all traces of vpnmon-r3 from your router...

vuninstall()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Uninstall Utility                                                                     ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} You are about to uninstall VPNMON-R3!  This action is irreversible."
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Do you wish to proceed?${CClear}"
  if promptyn "(y/n): "; then
    echo ""
    echo -e "\nAre you sure? Please type 'y' to validate you wish to proceed.${CClear}"
      if promptyn "[y/n]: "; then
        clear
        #Remove and uninstall files/directories
        rm -f -r /jffs/addons/vpnmon-r3.d
        rm -f /jffs/scripts/vpnmon-r3.sh
        sed -i -e '/vpnmon-r3.sh/d' /jffs/scripts/services-start
        cru d RunVPNMONR3reset
        echo ""
        echo -e "\nVPNMON-R3 has been uninstalled...${CClear}"
        echo ""
        exit 0
      else
        echo ""
        echo -e "\nExiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  else
    echo ""
    echo -e "\nExiting Uninstall Utility...${CClear}"
    sleep 1
    return
  fi
done
}

# -------------------------------------------------------------------------------------------------------------------------
# vlogs is a function that calls the nano text editor to view the BACKUPMON log file

vlogs()
{

export TERM=linux
nano +999999 --linenumbers $logfile
timer="$timerloop"

}

# -------------------------------------------------------------------------------------------------------------------------
# vpnslots lets you pick which vpn slot numbers are being monitored by vpnmon-r3

vpnslots()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN/WG Client Slot Monitoring                                                         ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which VPN/WG slots you would like VPNMON-R3 to monitor, or to${CClear}"
  echo -e "${InvGreen} ${CClear} alternatively reset the connected time on an active VPN/WG connection. Monitoring${CClear}"
  echo -e "${InvGreen} ${CClear} a VPN/WG connection ensures that VPNMON-R3 will actively keep a watch over it, and${CClear}"
  echo -e "${InvGreen} ${CClear} will reset it should the connection go down, or ping times go above set limits.${CClear}"
  echo -e "${InvGreen} ${CClear} A Connection Time reset may be necessary for WG connections at times, as a router${CClear}"
  echo -e "${InvGreen} ${CClear} reboot will start the WG tunnels up before VPNMON-R3 is able to start, and is not${CClear}"
  echo -e "${InvGreen} ${CClear} aware that they were restarted.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to enable/disable monitoring or to reset the time${CClear}"
  echo -e "${InvGreen} ${CClear} for each connected slot:${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"

    if [ "$availableslots" = "1 2" ]
    then
      if [ "$VPN1" = "1" ]; then VPN1Disp="${CGreen}Y${CCyan}"; else VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN2" = "1" ]; then VPN2Disp="${CGreen}Y${CCyan}"; else VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi

      currtime=$(date +%s)
      if [ "$VPNTIMER1" -gt 0 ]; then timediffvpn1=$((currtime-VPNTIMER1)); sincelastresetvpn1=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn1/86400)) $(($timediffvpn1%86400/3600)) $(($timediffvpn1%3600/60))); else sincelastresetvpn1="${CDkGray}Disabled"; fi
      if [ "$VPNTIMER2" -gt 0 ]; then timediffvpn2=$((currtime-VPNTIMER2)); sincelastresetvpn2=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn2/86400)) $(($timediffvpn2%86400/3600)) $(($timediffvpn2%3600/60))); else sincelastresetvpn2="${CDkGray}Disabled"; fi

      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${CWhite}     Monitored? Y/N  ${CClear}|${CWhite}  Time Connected / Reset? ${CClear}"
      echo -e "${InvGreen} ${CClear}                      |"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp         |  ${CGreen}(!) -${CClear} $sincelastresetvpn1 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp         |  ${CGreen}(@) -${CClear} $sincelastresetvpn2 ${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo ""
      read -p "Please select? (1-2, !-@, e=Exit): " SelectSlot
        case $SelectSlot in
          1) currvpn1state="$(_VPN_GetClientState_ "1")"; if [ "$VPN1" = "0" ] && [ "$currvpn1state" -eq 2 ]; then VPN1=1; VPNTIMER1=$(date +%s); VPN1Disp="${CGreen}Y${CCyan}"; elif [ "$VPN1" = "1" ]; then VPN1=0; VPNTIMER2=0; VPN1Disp="${CRed}N${CCyan}"; fi;;
          2) currvpn2state="$(_VPN_GetClientState_ "2")"; if [ "$VPN2" = "0" ] && [ "$currvpn2state" -eq 2 ]; then VPN2=1; VPNTIMER2=$(date +%s); VPN2Disp="${CGreen}Y${CCyan}"; elif [ "$VPN2" = "1" ]; then VPN2=0; VPNTIMER2=0; VPN2Disp="${CRed}N${CCyan}"; fi;;
          [\!]) if [ "$VPN1" = "1" ]; then VPNTIMER1=$(date +%s); else VPNTIMER1=0; fi;;
          [\@]) if [ "$VPN2" = "1" ]; then VPNTIMER2=$(date +%s); else VPNTIMER2=0; fi;;
          [Ee])
             { echo 'VPN1='$VPN1
               echo 'VPN2='$VPN2
             } > /jffs/addons/vpnmon-r3.d/vr3clients.txt

             { echo 'VPNTIMER1='$VPNTIMER1
               echo 'VPNTIMER2='$VPNTIMER2
             } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN/WG Client Slot Monitoring configuration / Connection Time Resets Saved" >> $logfile
             timer="$timerloop"
             break;;
        esac

    elif [ "$availableslots" = "1 2 3 4 5" ]
    then
      if [ "$VPN1" = "1" ]; then VPN1Disp="${CGreen}Y${CClear}"; else VPN1=0; VPN1Disp="${CRed}N${CClear}"; fi
      if [ "$VPN2" = "1" ]; then VPN2Disp="${CGreen}Y${CClear}"; else VPN2=0; VPN2Disp="${CRed}N${CClear}"; fi
      if [ "$VPN3" = "1" ]; then VPN3Disp="${CGreen}Y${CClear}"; else VPN3=0; VPN3Disp="${CRed}N${CClear}"; fi
      if [ "$VPN4" = "1" ]; then VPN4Disp="${CGreen}Y${CClear}"; else VPN4=0; VPN4Disp="${CRed}N${CClear}"; fi
      if [ "$VPN5" = "1" ]; then VPN5Disp="${CGreen}Y${CClear}"; else VPN5=0; VPN5Disp="${CRed}N${CClear}"; fi
      if [ "$WG1" = "1" ]; then WG1Disp="${CGreen}Y${CClear}"; else WG1=0; WG1Disp="${CRed}N${CClear}"; fi
      if [ "$WG2" = "1" ]; then WG2Disp="${CGreen}Y${CClear}"; else WG2=0; WG2Disp="${CRed}N${CClear}"; fi
      if [ "$WG3" = "1" ]; then WG3Disp="${CGreen}Y${CClear}"; else WG3=0; WG3Disp="${CRed}N${CClear}"; fi
      if [ "$WG4" = "1" ]; then WG4Disp="${CGreen}Y${CClear}"; else WG4=0; WG4Disp="${CRed}N${CClear}"; fi
      if [ "$WG5" = "1" ]; then WG5Disp="${CGreen}Y${CClear}"; else WG5=0; WG5Disp="${CRed}N${CClear}"; fi

      currtime=$(date +%s)
      if [ "$VPNTIMER1" -gt 0 ]; then timediffvpn1=$((currtime-VPNTIMER1)); sincelastresetvpn1=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn1/86400)) $(($timediffvpn1%86400/3600)) $(($timediffvpn1%3600/60))); else sincelastresetvpn1="${CDkGray}Disabled"; fi
      if [ "$VPNTIMER2" -gt 0 ]; then timediffvpn2=$((currtime-VPNTIMER2)); sincelastresetvpn2=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn2/86400)) $(($timediffvpn2%86400/3600)) $(($timediffvpn2%3600/60))); else sincelastresetvpn2="${CDkGray}Disabled"; fi
      if [ "$VPNTIMER3" -gt 0 ]; then timediffvpn3=$((currtime-VPNTIMER3)); sincelastresetvpn3=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn3/86400)) $(($timediffvpn3%86400/3600)) $(($timediffvpn3%3600/60))); else sincelastresetvpn3="${CDkGray}Disabled"; fi
      if [ "$VPNTIMER4" -gt 0 ]; then timediffvpn4=$((currtime-VPNTIMER4)); sincelastresetvpn4=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn4/86400)) $(($timediffvpn4%86400/3600)) $(($timediffvpn4%3600/60))); else sincelastresetvpn4="${CDkGray}Disabled"; fi
      if [ "$VPNTIMER5" -gt 0 ]; then timediffvpn5=$((currtime-VPNTIMER5)); sincelastresetvpn5=$(printf '%dd %02dh:%02dm\n' $(($timediffvpn5/86400)) $(($timediffvpn5%86400/3600)) $(($timediffvpn5%3600/60))); else sincelastresetvpn5="${CDkGray}Disabled"; fi
      if [ "$WGTIMER1" -gt 0 ]; then timediffwg1=$((currtime-WGTIMER1)); sincelastresetwg1=$(printf '%dd %02dh:%02dm\n' $(($timediffwg1/86400)) $(($timediffwg1%86400/3600)) $(($timediffwg1%3600/60))); else sincelastresetwg1="${CDkGray}Disabled"; fi
      if [ "$WGTIMER2" -gt 0 ]; then timediffwg2=$((currtime-WGTIMER2)); sincelastresetwg2=$(printf '%dd %02dh:%02dm\n' $(($timediffwg2/86400)) $(($timediffwg2%86400/3600)) $(($timediffwg2%3600/60))); else sincelastresetwg2="${CDkGray}Disabled"; fi
      if [ "$WGTIMER3" -gt 0 ]; then timediffwg3=$((currtime-WGTIMER3)); sincelastresetwg3=$(printf '%dd %02dh:%02dm\n' $(($timediffwg3/86400)) $(($timediffwg3%86400/3600)) $(($timediffwg3%3600/60))); else sincelastresetwg3="${CDkGray}Disabled"; fi
      if [ "$WGTIMER4" -gt 0 ]; then timediffwg4=$((currtime-WGTIMER4)); sincelastresetwg4=$(printf '%dd %02dh:%02dm\n' $(($timediffwg4/86400)) $(($timediffwg4%86400/3600)) $(($timediffwg4%3600/60))); else sincelastresetwg4="${CDkGray}Disabled"; fi
      if [ "$WGTIMER5" -gt 0 ]; then timediffwg5=$((currtime-WGTIMER5)); sincelastresetwg5=$(printf '%dd %02dh:%02dm\n' $(($timediffwg5/86400)) $(($timediffwg5%86400/3600)) $(($timediffwg5%3600/60))); else sincelastresetwg5="${CDkGray}Disabled"; fi

      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${CWhite}     Monitored? Y/N  ${CClear}|${CWhite}  Time Connected / Reset? ${CClear}"
      echo -e "${InvGreen} ${CClear}                      |"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp         |  ${CGreen}(!) -${CClear} $sincelastresetvpn1 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp         |  ${CGreen}(@) -${CClear} $sincelastresetvpn2 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3) -${CClear} $VPN3Disp         |  ${CGreen}(#) -${CClear} $sincelastresetvpn3 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(4) -${CClear} $VPN4Disp         |  ${CGreen}($) -${CClear} $sincelastresetvpn4 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(5) -${CClear} $VPN5Disp         |  ${CGreen}(%) -${CClear} $sincelastresetvpn5 ${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG1${CClear} ${CGreen}(6) -${CClear} $WG1Disp         |  ${CGreen}(^) -${CClear} $sincelastresetwg1 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG2${CClear} ${CGreen}(7) -${CClear} $WG2Disp         |  ${CGreen}(&) -${CClear} $sincelastresetwg2 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG3${CClear} ${CGreen}(8) -${CClear} $WG3Disp         |  ${CGreen}(-) -${CClear} $sincelastresetwg3 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG4${CClear} ${CGreen}(9) -${CClear} $WG4Disp         |  ${CGreen}(+) -${CClear} $sincelastresetwg4 ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG5${CClear} ${CGreen}(0) -${CClear} $WG5Disp         |  ${CGreen}(=) -${CClear} $sincelastresetwg5 ${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo ""
      read -p "Please select? (1-0, !-=, e=Exit): " SelectSlot
        case $SelectSlot in
          1) currvpn1state="$(_VPN_GetClientState_ "1")"; if [ "$VPN1" = "0" ] && [ "$currvpn1state" -eq 2 ]; then VPN1=1; VPNTIMER1=$(date +%s); VPN1Disp="${CGreen}Y${CCyan}"; elif [ "$VPN1" = "1" ]; then VPN1=0; VPNTIMER2=0; VPN1Disp="${CRed}N${CCyan}"; fi;;
          2) currvpn2state="$(_VPN_GetClientState_ "2")"; if [ "$VPN2" = "0" ] && [ "$currvpn2state" -eq 2 ]; then VPN2=1; VPNTIMER2=$(date +%s); VPN2Disp="${CGreen}Y${CCyan}"; elif [ "$VPN2" = "1" ]; then VPN2=0; VPNTIMER2=0; VPN2Disp="${CRed}N${CCyan}"; fi;;
          3) currvpn3state="$(_VPN_GetClientState_ "3")"; if [ "$VPN3" = "0" ] && [ "$currvpn3state" -eq 2 ]; then VPN3=1; VPNTIMER3=$(date +%s); VPN3Disp="${CGreen}Y${CCyan}"; elif [ "$VPN3" = "1" ]; then VPN3=0; VPNTIMER3=0; VPN3Disp="${CRed}N${CCyan}"; fi;;
          4) currvpn4state="$(_VPN_GetClientState_ "4")"; if [ "$VPN4" = "0" ] && [ "$currvpn4state" -eq 2 ]; then VPN4=1; VPNTIMER4=$(date +%s); VPN4Disp="${CGreen}Y${CCyan}"; elif [ "$VPN4" = "1" ]; then VPN4=0; VPNTIMER4=0; VPN4Disp="${CRed}N${CCyan}"; fi;;
          5) currvpn5state="$(_VPN_GetClientState_ "5")"; if [ "$VPN5" = "0" ] && [ "$currvpn5state" -eq 2 ]; then VPN5=1; VPNTIMER5=$(date +%s); VPN5Disp="${CGreen}Y${CCyan}"; elif [ "$VPN5" = "1" ]; then VPN5=0; VPNTIMER5=0; VPN5Disp="${CRed}N${CCyan}"; fi;;
          6) currwg1state="$(_WG_GetClientState_ "1")"; if [ "$WG1" = "0" ] && [ "$currwg1state" -eq 2 ]; then WG1=1; WGTIMER1=$(date +%s); WG1Disp="${CGreen}Y${CCyan}"; elif [ "$WG1" = "1" ]; then WG1=0; WGTIMER1=0; WG1Disp="${CRed}N${CCyan}"; fi;;
          7) currwg2state="$(_WG_GetClientState_ "2")"; if [ "$WG2" = "0" ] && [ "$currwg2state" -eq 2 ]; then WG2=1; WGTIMER2=$(date +%s); WG2Disp="${CGreen}Y${CCyan}"; elif [ "$WG2" = "1" ]; then WG2=0; WGTIMER2=0; WG2Disp="${CRed}N${CCyan}"; fi;;
          8) currwg3state="$(_WG_GetClientState_ "3")"; if [ "$WG3" = "0" ] && [ "$currwg3state" -eq 2 ]; then WG3=1; WGTIMER3=$(date +%s); WG3Disp="${CGreen}Y${CCyan}"; elif [ "$WG3" = "1" ]; then WG3=0; WGTIMER3=0; WG3Disp="${CRed}N${CCyan}"; fi;;
          9) currwg4state="$(_WG_GetClientState_ "4")"; if [ "$WG4" = "0" ] && [ "$currwg4state" -eq 2 ]; then WG4=1; WGTIMER4=$(date +%s); WG4Disp="${CGreen}Y${CCyan}"; elif [ "$WG4" = "1" ]; then WG4=0; WGTIMER4=0; WG4Disp="${CRed}N${CCyan}"; fi;;
          0) currwg5state="$(_WG_GetClientState_ "5")"; if [ "$WG5" = "0" ] && [ "$currwg5state" -eq 2 ]; then WG5=1; WGTIMER5=$(date +%s); WG5Disp="${CGreen}Y${CCyan}"; elif [ "$WG5" = "1" ]; then WG5=0; WGTIMER5=0; WG5Disp="${CRed}N${CCyan}"; fi;;
          [\!]) if [ "$VPN1" = "1" ]; then VPNTIMER1=$(date +%s); else VPNTIMER1=0; fi;;
          [\@]) if [ "$VPN2" = "1" ]; then VPNTIMER2=$(date +%s); else VPNTIMER2=0; fi;;
          [\#]) if [ "$VPN3" = "1" ]; then VPNTIMER3=$(date +%s); else VPNTIMER3=0; fi;;
          [\$]) if [ "$VPN4" = "1" ]; then VPNTIMER4=$(date +%s); else VPNTIMER4=0; fi;;
          [\%]) if [ "$VPN5" = "1" ]; then VPNTIMER5=$(date +%s); else VPNTIMER5=0; fi;;
          [\^]) if [ "$WG1" = "1" ]; then WGTIMER1=$(date +%s); else WGTIMER1=0; fi;;
          [\&]) if [ "$WG2" = "1" ]; then WGTIMER2=$(date +%s); else WGTIMER2=0; fi;;
          [\-]) if [ "$WG3" = "1" ]; then WGTIMER3=$(date +%s); else WGTIMER3=0; fi;;
          [\+]) if [ "$WG4" = "1" ]; then WGTIMER4=$(date +%s); else WGTIMER4=0; fi;;
          [\=]) if [ "$WG5" = "1" ]; then WGTIMER5=$(date +%s); else WGTIMER5=0; fi;;
          [Ee])
             { echo 'VPN1='$VPN1
               echo 'VPN2='$VPN2
               echo 'VPN3='$VPN3
               echo 'VPN4='$VPN4
               echo 'VPN5='$VPN5
               echo 'WG1='$WG1
               echo 'WG2='$WG2
               echo 'WG3='$WG3
               echo 'WG4='$WG4
               echo 'WG5='$WG5
             } > /jffs/addons/vpnmon-r3.d/vr3clients.txt

             { echo 'VPNTIMER1='$VPNTIMER1
               echo 'VPNTIMER2='$VPNTIMER2
               echo 'VPNTIMER3='$VPNTIMER3
               echo 'VPNTIMER4='$VPNTIMER4
               echo 'VPNTIMER5='$VPNTIMER5
               echo 'WGTIMER1='$WGTIMER1
               echo 'WGTIMER2='$WGTIMER2
               echo 'WGTIMER3='$WGTIMER3
               echo 'WGTIMER4='$WGTIMER4
               echo 'WGTIMER5='$WGTIMER5
             } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN/WG Client Slot Monitoring configuration / Connection Time Resets Saved" >> $logfile
             timer="$timerloop"
             break;;
      esac
    fi
done

}

# -------------------------------------------------------------------------------------------------------------------------
# amtmevents lets you pick success or failure amtm email notification selections

amtmevents()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} AMTM Email Notifications                                                              ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate if you would like VPNMON-R3 to send you email notifications for WAN${CClear}"
  echo -e "${InvGreen} ${CClear} or VPN slot failures, or successes on scheduled VPN resets, or both?  PLEASE NOTE:${CClear}"
  echo -e "${InvGreen} ${CClear} This does require that AMTM email has been set up successfully under AMTM -> em${CClear}"
  echo -e "${InvGreen} ${CClear} (email settings). Once you are able to send and receive test emails from AMTM, you${CClear}"
  echo -e "${InvGreen} ${CClear} may use this functionality in VPNMON-R3. Additionally, this functionality will${CClear}"
  echo -e "${InvGreen} ${CClear} download an AMTM email interface library courtesy of @Martinsky, and will be${CClear}"
  echo -e "${InvGreen} ${CClear} located under a new common shared library folder called: /jffs/addons/shared-libs.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Secondarily, you can choose to rate limit the rate at which emails are sent to${CClear}"
  echo -e "${InvGreen} ${CClear} your email account per hour. (0=Disabled, 1-9999)${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to enable/disable email event notifications:${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"

  if [ "$amtmemailsuccess" = "1" ]; then amtmemailsuccessdisp="${CGreen}Y${CCyan}"; else amtmemailsuccess=0; amtmemailsuccessdisp="${CRed}N${CCyan}"; saveconfig; fi
  if [ "$amtmemailfailure" = "1" ]; then amtmemailfailuredisp="${CGreen}Y${CCyan}"; else amtmemailfailure=0; amtmemailfailuredisp="${CRed}N${CCyan}"; saveconfig; fi
  if [ "$ratelimit" = "0" ]; then ratelimitdisp="Disabled"; else ratelimitdisp=$ratelimit; fi
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN Success Event Notifications${CClear} ${CGreen}(1) -${CClear} $amtmemailsuccessdisp${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN Failure Event Notifications${CClear} ${CGreen}(2) -${CClear} $amtmemailfailuredisp${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}Set Email Rate Limit (per hour)${CClear} ${CGreen}(r) - $ratelimitdisp${CClear}"
  echo ""
  read -p "Please select? (1-2, r=Set Email Rate Limit, t=Test Email, e=Exit): " SelectSlot
    case $SelectSlot in
      1) if [ "$amtmemailsuccess" = "0" ]; then amtmemailsuccess=1; amtmemailsuccessdisp="${CGreen}Y${CCyan}"; elif [ "$amtmemailsuccess" = "1" ]; then amtmemailsuccess=0; amtmemailsuccessdisp="${CRed}N${CCyan}"; fi;;
      2) if [ "$amtmemailfailure" = "0" ]; then amtmemailfailure=1; amtmemailfailuredisp="${CGreen}Y${CCyan}"; elif [ "$amtmemailfailure" = "1" ]; then amtmemailfailure=0; amtmemailfailuredisp="${CRed}N${CCyan}"; fi;;
      [Tt])
         if [ -f "$CUSTOM_EMAIL_LIBFile" ]
         then
             . "$CUSTOM_EMAIL_LIBFile"

             if [ -z "${CEM_LIB_VERSION:+xSETx}" ] || \
                _CheckLibraryUpdates_CEM_ "$CUSTOM_EMAIL_LIBDir" quiet
             then
                 _DownloadCEMLibraryFile_ "update"
             fi
         else
             _DownloadCEMLibraryFile_ "install"
         fi

         cemIsFormatHTML=true
         cemIsVerboseMode=true  ## true OR false ##
         emailBodyTitle="Testing Email Notification"
         emailSubject="TEST: VPNMON-R3 Email Notification"
         tmpEMailBodyFile="/tmp/var/tmp/tmpEMailBody_${scriptFileNTag}.$$.TXT"

         {
           printf "This is a <b>TEST</b> to check & verify if sending email notifications is working well from <b>VPNMON-R3</b>.\n"
         } > "$tmpEMailBodyFile"

         _SendEMailNotification_ "VPNMON-R3 v$version" "$emailSubject" "$tmpEMailBodyFile" "$emailBodyTitle"

         echo ; echo
         read -rsp $'Press any key to acknowledge...\n' -n1 key
         ;;

      [Rr])
         echo ""
         read -p "Please enter new Email Rate Limit (per hour)? (0=disabled, 1-9999, e=Exit): " newratelimit
         if [ "$newratelimit" = "e" ]
         then
             echo -e "\n[Exiting]"; sleep 2
         elif echo "$newratelimit" | grep -qE "^(0|[1-9][0-9]{0,3})$" && \
             [ "$newratelimit" -ge 0 ] && [ "$newratelimit" -le 9999 ]
         then
             ratelimit="$newratelimit"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Email Rate Limit entered (per hour): $ratelimit" >> $logfile
             saveconfig
         else
             previousValue="$ratelimit"
             ratelimit="${ratelimit:=0}"
             [ "$ratelimit" != "$previousValue" ] && \
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Email Rate Limit entered (per hour): $ratelimit" >> $logfile
             saveconfig
         fi
         ;;

      [Ee])
         saveconfig
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: AMTM Email notification configuration saved" >> $logfile
         timer="$timerloop"
         break;;
    esac
done

}

# -------------------------------------------------------------------------------------------------------------------------
# vpnserverlistmaint lets you pick which vpn slot server list you want to edit/maintain

vpnserverlistmaint()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Client Slot Server List Maintenance                                               ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which VPN Slot Server List you would like to edit/maintain.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to launch and edit the list with the NANO text editor${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} VPN INSTRUCTIONS: Enter a single column of IP addresses or hostnames, as required by${CClear}"
  echo -e "${InvGreen} ${CClear} your VPN provider. ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} NANO INSTRUCTIONS: CTRL-O + Enter (save), CTRL-X (exit)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3svr1.txt ]; then
      iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr1.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $iplist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3svr2.txt ]; then
      iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr2.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $iplist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  if [ "$availableslots" = "1 2" ]
  then
    echo ""
    read -p "Please select? (1-2, e=Exit): " SelectSlot
    case $SelectSlot in
      1) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr1.txt;;
      2) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr2.txt;;
      [Ee])
        timer="$timerloop"
        break;;
    esac
  fi

  if [ "$availableslots" = "1 2 3 4 5" ]
  then
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3)${CClear}"
      if [ -f /jffs/addons/vpnmon-r3.d/vr3svr3.txt ]; then
        iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr3.txt | sed 's/,$/\n/')
        echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $iplist
      else
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(4)${CClear}"
      if [ -f /jffs/addons/vpnmon-r3.d/vr3svr4.txt ]; then
        iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr4.txt | sed 's/,$/\n/')
        echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $iplist
      else
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(5)${CClear}"
      if [ -f /jffs/addons/vpnmon-r3.d/vr3svr5.txt ]; then
        iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr5.txt | sed 's/,$/\n/')
        echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $iplist
      else
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      fi
    echo ""
    read -p "Please select? (1-5, e=Exit): " SelectSlot
    case $SelectSlot in
      1) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr1.txt;;
      2) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr2.txt;;
      3) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr3.txt;;
      4) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr4.txt;;
      5) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr5.txt;;
      [Ee])
        timer="$timerloop"
        break;;
    esac
  fi

done

}

# -------------------------------------------------------------------------------------------------------------------------
# wgserverlistmaint lets you pick which wg slot server list you want to edit/maintain

wgserverlistmaint()
{

if [ "$availableslots" = "1 2" ]
  then
    return
fi

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} WG Client Slot Server List Maintenance                                                ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which WG Slot Server List you would like to edit/maintain.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to launch and edit the list with the NANO text editor${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} WG INSTRUCTIONS: Enter a 7-field comma-delimited row of WG Connections${CClear}"
  echo -e "${InvGreen} ${CClear} Format: ${CWhite}ConnectionName,InterfaceIP/Sub,EndpointIP,EndpointPort,PrivateKey,PublicKey,PreSharedKey(Opt)${CClear}"
  echo -e "${InvGreen} ${CClear} Example: ${CGreen}City WG,10.50.0.2/32,143.32.55.23,34334,fasdkaffkasdjfj=,221t949as2323kf=,23fj39fffjdaf=${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} NANO INSTRUCTIONS: CTRL-O + Enter (save), CTRL-X (exit)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG1${CClear} ${CGreen}(6)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt ]; then
      wglist=$(awk -F, '{printf "%s%s", sep, $1; sep=","} END {print ""}' /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt | awk '{print substr($0, 1, 75) ">"}')
      echo -en "${InvGreen} ${CClear} Contents: "; echo $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG2${CClear} ${CGreen}(7)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt ]; then
      wglist=$(awk -F, '{printf "%s%s", sep, $1; sep=","} END {print ""}' /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt | awk '{print substr($0, 1, 75) ">"}')
      echo -en "${InvGreen} ${CClear} Contents: "; echo $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG3${CClear} ${CGreen}(8)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt ]; then
      wglist=$(awk -F, '{printf "%s%s", sep, $1; sep=","} END {print ""}' /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt | awk '{print substr($0, 1, 75) ">"}')
      echo -en "${InvGreen} ${CClear} Contents: "; echo $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG4${CClear} ${CGreen}(9)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt ]; then
      wglist=$(awk -F, '{printf "%s%s", sep, $1; sep=","} END {print ""}' /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt | awk '{print substr($0, 1, 75) ">"}')
      echo -en "${InvGreen} ${CClear} Contents: "; echo $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG5${CClear} ${CGreen}(0)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt ]; then
      wglist=$(awk -F, '{printf "%s%s", sep, $1; sep=","} END {print ""}' /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt | awk '{print substr($0, 1, 75) ">"}')
      echo -en "${InvGreen} ${CClear} Contents: "; echo $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo ""
  read -p "Please select? (6-0, e=Exit): " SelectSlot
  case $SelectSlot in
    6) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt;;
    7) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt;;
    8) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt;;
    9) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt;;
    0) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt;;
    [Ee])
      timer="$timerloop"
      break;;
  esac

done

}

# -------------------------------------------------------------------------------------------------------------------------
# vpnserverlistautomation lets you pick which vpn slot server list automation you want to edit/execute

vpnserverlistautomation()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} WG/VPN Client Slot Server List Automation                                             ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which VPN Slot Automation Script you would like to edit/execute.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to edit or launch your update statements${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} VPN INSTRUCTIONS: Insert CURL statement that outputs a single-column Server IP list${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} WG INSTRUCTIONS: Insert CURL statement that outputs a 7-field comma-separated list${CClear}"
  echo -e "${InvGreen} ${CClear} Format: ${CWhite}ConnectionName,InterfaceIP/Sub,EndpointIP,EndpointPort,PrivateKey,PublicKey,PreSharedKey(Opt)${CClear}"
  echo -e "${InvGreen} ${CClear} Example: ${CGreen}City WG,10.50.0.2/32,143.32.55.23,34334,fasdkaffkasdjfj=,221t949as2323kf=,23fj39fffjdaf=${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(e1)${CClear} View/Edit | ${CGreen}(x1)${CClear} Execute | ${CGreen}(s1)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation1" ] || [ "$automation1" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation1unenc=$(echo "$automation1" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation1unenc"
    fi
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(e2)${CClear} View/Edit | ${CGreen}(x2)${CClear} Execute | ${CGreen}(s2)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation2" ] || [ "$automation2" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation2unenc=$(echo "$automation2" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation2unenc"
    fi
  echo -e "${InvGreen} ${CClear}"

  if [ "$availableslots" = "1 2" ]; then
    echo ""
    read -p "Please select? (e1-e2, x1-x2, s1-s2, e=Exit): " SelectSlot2
    case $SelectSlot2 in
      e1)
         echo ""
         if [ "$automation1" = "" ] || [ -z "$automation1" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation1" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation1new
         if [ "$automation1new" = "" ] || [ -z "$automation1new" ]; then
           automation1=""
           saveconfig
         elif [ "$automation1new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation1=`echo $automation1new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 1" >> $logfile
           saveconfig
         fi
      ;;

      x1)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation1unenc=$(echo "$automation1" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation1unenc"
         echo ""
         eval "$automation1unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr1.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 1 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 1" >> $logfile
             echo ""
             skynetwhitelist 1
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 1 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s1)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr1.txt "VPNMON-R3 VPN Slot 1 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 1 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 1" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      e2)
         echo ""
         if [ "$automation2" = "" ] || [ -z "$automation2" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation2" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation2new
         if [ "$automation2new" = "" ] || [ -z "$automation2new" ]; then
           automation2=""
           saveconfig
         elif [ "$automation2new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation2=`echo $automation2new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 2" >> $logfile
           saveconfig
         fi
      ;;

      x2)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation2unenc=$(echo "$automation2" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation2unenc"
         echo ""
         eval "$automation2unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr2.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 2 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 2" >> $logfile
             echo ""
             skynetwhitelist 2
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 2 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s2)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr2.txt "VPNMON-R3 VPN Slot 2 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 2 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 2" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      [Ee])
            timer="$timerloop"
            break;;
    esac
  fi

  if [ "$availableslots" = "1 2 3 4 5" ]; then
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(e3)${CClear} View/Edit | ${CGreen}(x3)${CClear} Execute | ${CGreen}(s3)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation3" ] || [ "$automation3" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation3unenc=$(echo "$automation3" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation3unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(e4)${CClear} View/Edit | ${CGreen}(x4)${CClear} Execute | ${CGreen}(s4)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation4" ] || [ "$automation4" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation4unenc=$(echo "$automation4" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation4unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(e5)${CClear} View/Edit | ${CGreen}(x5)${CClear} Execute | ${CGreen}(s5)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation5" ] || [ "$automation5" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation5unenc=$(echo "$automation5" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation5unenc"
    fi
    echo -e "${InvGreen} ${CClear}"

    ##-------------------------------------##
    ## Added by Dan G. [2025-Jul-15]       ##
    ##-------------------------------------##

    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG1${CClear} ${CGreen}(e6)${CClear} View/Edit | ${CGreen}(x6)${CClear} Execute | ${CGreen}(s6)${CClear} Skynet WL Import${CClear}"
      if [ -z "$wgautomation1" ] || [ "$wgautomation1" = "" ]; then
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      else
        wgautomation1unenc=$(echo "$wgautomation1" | openssl enc -d -base64 -A)
        echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation1unenc"
      fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG2${CClear} ${CGreen}(e7)${CClear} View/Edit | ${CGreen}(x7)${CClear} Execute | ${CGreen}(s7)${CClear} Skynet WL Import${CClear}"
      if [ -z "$wgautomation2" ] || [ "$wgautomation2" = "" ]; then
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      else
        wgautomation2unenc=$(echo "$wgautomation2" | openssl enc -d -base64 -A)
        echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation2unenc"
      fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG3${CClear} ${CGreen}(e8)${CClear} View/Edit | ${CGreen}(x8)${CClear} Execute | ${CGreen}(s8)${CClear} Skynet WL Import${CClear}"
    if [ -z "$wgautomation3" ] || [ "$wgautomation3" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      wgautomation3unenc=$(echo "$wgautomation3" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation3unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG4${CClear} ${CGreen}(e9)${CClear} View/Edit | ${CGreen}(x9)${CClear} Execute | ${CGreen}(s9)${CClear} Skynet WL Import${CClear}"
    if [ -z "$wgautomation4" ] || [ "$wgautomation4" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      wgautomation4unenc=$(echo "$wgautomation4" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation4unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG5${CClear} ${CGreen}(e0)${CClear} View/Edit | ${CGreen}(x0)${CClear} Execute | ${CGreen}(s0)${CClear} Skynet WL Import${CClear}"
    if [ -z "$wgautomation5" ] || [ "$wgautomation5" = "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      wgautomation5unenc=$(echo "$wgautomation5" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation5unenc"
    fi
    echo ""
    read -p "Please select? (e1-e0, x1-x0, s1-s0, e=Exit): " SelectSlot5
    case $SelectSlot5 in
      e1)
         echo ""
         if [ "$automation1" = "" ] || [ -z "$automation1" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation1" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation1new
         if [ "$automation1new" = "" ] || [ -z "$automation1new" ]; then
           automation1=""
           saveconfig
         elif [ "$automation1new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation1=`echo $automation1new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 1" >> $logfile
           saveconfig
         fi
      ;;

      x1)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation1unenc=$(echo "$automation1" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation1unenc"
         echo ""
         eval "$automation1unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr1.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 1 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 1" >> $logfile
             echo ""
             skynetwhitelist 1
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 1 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s1)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr1.txt "VPNMON-R3 VPN Slot 1 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 1 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 1" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      e2)
         echo ""
         if [ "$automation2" = "" ] || [ -z "$automation2" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation2" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation2new
         if [ "$automation2new" = "" ] || [ -z "$automation2new" ]; then
           automation2=""
           saveconfig
         elif [ "$automation2new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation2=`echo $automation2new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 2" >> $logfile
           saveconfig
         fi
      ;;

      x2)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation2unenc=$(echo "$automation2" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation2unenc"
         echo ""
         eval "$automation2unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr2.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 2 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 2" >> $logfile
             echo ""
             skynetwhitelist 2
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 2 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s2)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr2.txt "VPNMON-R3 VPN Slot 2 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 2 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 2" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      e3)
         echo ""
         if [ "$automation3" = "" ] || [ -z "$automation3" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation3" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation3new
         if [ "$automation3new" = "" ] || [ -z "$automation3new" ]; then
           automation3=""
           saveconfig
         elif [ "$automation3new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation3=`echo $automation3new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 3" >> $logfile
           saveconfig
         fi
      ;;

      x3)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation3unenc=$(echo "$automation3" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation3unenc"
         echo ""
         eval "$automation3unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr3.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 3 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 3" >> $logfile
             echo ""
             skynetwhitelist 3
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 3 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s3)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr3.txt "VPNMON-R3 VPN Slot 3 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 3 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 3" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      e4)
         echo ""
         if [ "$automation4" ="" ] || [ -z "$automation4" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation4" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation4new
         if [ "$automation4new" = "" ] || [ -z "$automation4new" ]; then
           automation4=""
           saveconfig
         elif [ "$automation4new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation4=`echo $automation4new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 4" >> $logfile
           saveconfig
         fi
      ;;

      x4)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation4unenc=$(echo "$automation4" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation4unenc"
         echo ""
         eval "$automation4unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr4.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 4 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 4" >> $logfile
             echo ""
             skynetwhitelist 4
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 4 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s4)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr4.txt "VPNMON-R3 VPN Slot 4 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 4 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 4" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      e5)
         echo ""
         if [ "$automation5" = "" ] || [ -z "$automation5" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation5" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation5new
         if [ "$automation5new" = "" ] || [ -z "$automation5new" ]; then
           automation5=""
           saveconfig
         elif [ "$automation5new" = "e" ]; then
           echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
         else
           automation5=`echo $automation5new | openssl enc -base64 -A`
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 5" >> $logfile
           saveconfig
         fi
      ;;

      x5)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation5unenc=$(echo "$automation5" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation5unenc"
         echo ""
         eval "$automation5unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
           if [ $dlcnt -lt 1 ]; then
             dlcnt=0
           elif [ -z $dlcnt ]; then
             dlcnt=0
           fi
         else
           dlcnt=0
         fi

         if [ "$dlcnt" -gt 1 ]
           then
             cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr5.txt" >/dev/null 2>&1
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
             echo ""
             echo -e "${CGreen}[Saved to VPN Client Slot 5 Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Execution Complete]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 5" >> $logfile
             echo ""
             skynetwhitelist 5
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
           else
             rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
             echo ""
             echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
             echo ""
             echo -e "${CGreen}[Please check Query Language or VPN Service API may be down]${CClear}"
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot 5 yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
             echo ""
             read -rsp $'Press any key to acknowledge...\n' -n1 key
         fi
      ;;

      s5)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr5.txt "VPNMON-R3 VPN Slot 5 Manually Whitelisted on $date" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 5 Imported]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 5" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

     e6)
       echo ""
       if [ "$wgautomation1" = "" ] || [ -z "$wgautomation1" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation1" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation1new
       if [ "$wgautomation1new" = "" ] || [ -z "$wgautomation1new" ]; then
         wgautomation1=""
         saveconfig
       elif [ "$wgautomation1new" = "e" ]; then
         echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
       else
         wgautomation1=`echo $wgautomation1new | openssl enc -base64 -A`
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom WG Server List Command entered for WG Slot 1" >> $logfile
         saveconfig
       fi
    ;;

    x6)
       echo ""
       echo -e "${CGreen}[Executing Script]${CClear}"
       wgautomation1unenc=$(echo "$wgautomation1" | openssl enc -d -base64 -A)
       echo -e "${CClear}Running: $wgautomation1unenc"
       echo ""
       eval "$wgautomation1unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       #Determine how many server entries are in each of the vpn slot alternate server files
       if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
         dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
         if [ $dlcnt -lt 1 ]; then
           dlcnt=0
         elif [ -z $dlcnt ]; then
           dlcnt=0
         fi
       else
         dlcnt=0
       fi

       if [ "$dlcnt" -gt 1 ]
         then
           cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt" >/dev/null 2>&1
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
           echo ""
           echo -e "${CGreen}[Saved to WG Client Slot 1 Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Execution Complete]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom WG Server List Command executed for WG Slot 1" >> $logfile
           echo ""
           skynetwhitelist wg1
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
         else
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Please check Query Language or WG Service API may be down]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List Query for WG Slot 1 yielded 0 rows -- Query may be invalid or WG API service may be down" >> $logfile
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
       fi
    ;;

    s6)
       echo ""
       echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
       awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 1 Manually Whitelisted on $date" >/dev/null 2>&1
       rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
       echo ""
       echo -e "${CGreen}[Contents of WG Slot 1 Imported]${CClear}"
       echo ""
       echo -e "${CGreen}[Execution Complete]${CClear}"
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for WG Slot 1" >> $logfile
       echo ""
       read -rsp $'Press any key to acknowledge...\n' -n1 key
    ;;

    e7)
       echo ""
       if [ "$wgautomation2" = "" ] || [ -z "$wgautomation2" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation2" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation2new
       if [ "$wgautomation2new" = "" ] || [ -z "$wgautomation2new" ]; then
         wgautomation2=""
         saveconfig
       elif [ "$wgautomation2new" = "e" ]; then
         echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
       else
         wgautomation2=`echo $wgautomation2new | openssl enc -base64 -A`
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom WG Server List Command entered for WG Slot 2" >> $logfile
         saveconfig
       fi
    ;;

    x7)
       echo ""
       echo -e "${CGreen}[Executing Script]${CClear}"
       wgautomation2unenc=$(echo "$wgautomation2" | openssl enc -d -base64 -A)
       echo -e "${CClear}Running: $wgautomation2unenc"
       echo ""
       eval "$wgautomation2unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       #Determine how many server entries are in each of the vpn slot alternate server files
       if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
         dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
         if [ $dlcnt -lt 1 ]; then
           dlcnt=0
         elif [ -z $dlcnt ]; then
           dlcnt=0
         fi
       else
         dlcnt=0
       fi

       if [ "$dlcnt" -gt 1 ]
         then
           cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt" >/dev/null 2>&1
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
           echo ""
           echo -e "${CGreen}[Saved to WG Client Slot 2 Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Execution Complete]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom WG Server List Command executed for WG Slot 2" >> $logfile
           echo ""
           skynetwhitelist wg2
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
         else
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Please check Query Language or WG Service API may be down]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List Query for WG Slot 2 yielded 0 rows -- Query may be invalid or WG API service may be down" >> $logfile
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
       fi
    ;;

    s7)
       echo ""
       echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
       awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 2 Manually Whitelisted on $date" >/dev/null 2>&1
       rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
       echo ""
       echo -e "${CGreen}[Contents of WG Slot 2 Imported]${CClear}"
       echo ""
       echo -e "${CGreen}[Execution Complete]${CClear}"
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for WG Slot 2" >> $logfile
       echo ""
       read -rsp $'Press any key to acknowledge...\n' -n1 key
    ;;

    e8)
       echo ""
       if [ "$wgautomation3" = "" ] || [ -z "$wgautomation3" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation3" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation3new
       if [ "$wgautomation3new" = "" ] || [ -z "$wgautomation3new" ]; then
         wgautomation3=""
         saveconfig
       elif [ "$wgautomation3new" = "e" ]; then
         echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
       else
         wgautomation3=`echo $wgautomation3new | openssl enc -base64 -A`
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom WG Server List Command entered for WG Slot 3" >> $logfile
         saveconfig
       fi
    ;;

    x8)
       echo ""
       echo -e "${CGreen}[Executing Script]${CClear}"
       wgautomation3unenc=$(echo "$wgautomation3" | openssl enc -d -base64 -A)
       echo -e "${CClear}Running: $wgautomation3unenc"
       echo ""
       eval "$wgautomation3unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       #Determine how many server entries are in each of the vpn slot alternate server files
       if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
         dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
         if [ $dlcnt -lt 1 ]; then
           dlcnt=0
         elif [ -z $dlcnt ]; then
           dlcnt=0
         fi
       else
         dlcnt=0
       fi

       if [ "$dlcnt" -gt 1 ]
         then
           cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt" >/dev/null 2>&1
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
           echo ""
           echo -e "${CGreen}[Saved to WG Client Slot 3 Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Execution Complete]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom WG Server List Command executed for WG Slot 3" >> $logfile
           echo ""
           skynetwhitelist wg3
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
         else
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Please check Query Language or WG Service API may be down]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List Query for WG Slot 3 yielded 0 rows -- Query may be invalid or WG API service may be down" >> $logfile
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
       fi
    ;;

    s8)
       echo ""
       echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
       awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 3 Manually Whitelisted on $date" >/dev/null 2>&1
       rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
       echo ""
       echo -e "${CGreen}[Contents of WG Slot 3 Imported]${CClear}"
       echo ""
       echo -e "${CGreen}[Execution Complete]${CClear}"
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for WG Slot 3" >> $logfile
       echo ""
       read -rsp $'Press any key to acknowledge...\n' -n1 key
    ;;

    e9)
       echo ""
       if [ "$wgautomation4" = "" ] || [ -z "$wgautomation4" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation4" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation4new
       if [ "$wgautomation4new" = "" ] || [ -z "$wgautomation4new" ]; then
         wgautomation4=""
         saveconfig
       elif [ "$wgautomation4new" = "e" ]; then
         echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
       else
         wgautomation4=`echo $wgautomation4new | openssl enc -base64 -A`
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom WG Server List Command entered for WG Slot 4" >> $logfile
         saveconfig
       fi
    ;;

    x9)
       echo ""
       echo -e "${CGreen}[Executing Script]${CClear}"
       wgautomation4unenc=$(echo "$wgautomation4" | openssl enc -d -base64 -A)
       echo -e "${CClear}Running: $wgautomation4unenc"
       echo ""
       eval "$wgautomation4unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       #Determine how many server entries are in each of the vpn slot alternate server files
       if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
         dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
         if [ $dlcnt -lt 1 ]; then
           dlcnt=0
         elif [ -z $dlcnt ]; then
           dlcnt=0
         fi
       else
         dlcnt=0
       fi

       if [ "$dlcnt" -gt 1 ]
         then
           cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt" >/dev/null 2>&1
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
           echo ""
           echo -e "${CGreen}[Saved to WG Client Slot 4 Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Execution Complete]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom WG Server List Command executed for WG Slot 4" >> $logfile
           echo ""
           skynetwhitelist wg4
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
         else
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Please check Query Language or WG Service API may be down]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List Query for WG Slot 4 yielded 0 rows -- Query may be invalid or WG API service may be down" >> $logfile
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
       fi
    ;;

    s9)
       echo ""
       echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
       awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 4 Manually Whitelisted on $date" >/dev/null 2>&1
       rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
       echo ""
       echo -e "${CGreen}[Contents of WG Slot 4 Imported]${CClear}"
       echo ""
       echo -e "${CGreen}[Execution Complete]${CClear}"
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for WG Slot 4" >> $logfile
       echo ""
       read -rsp $'Press any key to acknowledge...\n' -n1 key
    ;;

    e0)
       echo ""
       if [ "$wgautomation5" = "" ] || [ -z "$wgautomation5" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation5" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation5new
       if [ "$wgautomation5new" = "" ] || [ -z "$wgautomation5new" ]; then
         wgautomation5=""
         saveconfig
       elif [ "$wgautomation5new" = "e" ]; then
         echo ""; echo -e "${CGreen}[Exiting]${CClear}"; sleep 1
       else
         wgautomation5=`echo $wgautomation5new | openssl enc -base64 -A`
         echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Custom WG Server List Command entered for WG Slot 5" >> $logfile
         saveconfig
       fi
    ;;

    x0)
       echo ""
       echo -e "${CGreen}[Executing Script]${CClear}"
       wgautomation5unenc=$(echo "$wgautomation5" | openssl enc -d -base64 -A)
       echo -e "${CClear}Running: $wgautomation5unenc"
       echo ""
       eval "$wgautomation5unenc" > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       #Determine how many server entries are in each of the vpn slot alternate server files
       if [ -f /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt ]; then
         dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt | wc -l) >/dev/null 2>&1
         if [ $dlcnt -lt 1 ]; then
           dlcnt=0
         elif [ -z $dlcnt ]; then
           dlcnt=0
         fi
       else
         dlcnt=0
       fi

       if [ "$dlcnt" -gt 1 ]
         then
           cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt" >/dev/null 2>&1
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
           echo ""
           echo -e "${CGreen}[Saved to WG Client Slot 5 Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Execution Complete]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom WG Server List Command executed for WG Slot 5" >> $logfile
           echo ""
           skynetwhitelist wg5
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
         else
           rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
           echo ""
           echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
           echo ""
           echo -e "${CGreen}[Please check Query Language or WG Service API may be down]${CClear}"
           echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List Query for WG Slot 5 yielded 0 rows -- Query may be invalid or WG API service may be down" >> $logfile
           echo ""
           read -rsp $'Press any key to acknowledge...\n' -n1 key
       fi
    ;;

    s0)
       echo ""
       echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
       awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 5 Manually Whitelisted on $date" >/dev/null 2>&1
       rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
       echo ""
       echo -e "${CGreen}[Contents of WG Slot 5 Imported]${CClear}"
       echo ""
       echo -e "${CGreen}[Execution Complete]${CClear}"
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for WG Slot 5" >> $logfile
       echo ""
       read -rsp $'Press any key to acknowledge...\n' -n1 key
    ;;

     [Ee])
           timer="$timerloop"
           break;;

    esac
  fi

done

}

# -------------------------------------------------------------------------------------------------------------------------
# timerloopconfig lets you configure how long you want the timer cycle to last between vpn connection checks

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
timerloopconfig()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Timer Loop Configuration / Recovery Timeout Opportunities                             ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate how long the timer cycle should take between Connectivity checks,${CClear}"
  echo -e "${InvGreen} ${CClear} as well as the number of Recovery Timeout Opportunities the loop should complete${CClear}"
  echo -e "${InvGreen} ${CClear} before issuing a connection reset.${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Recovery Timeout Opportunities are simply the number of chances the script will${CClear}"
  echo -e "${InvGreen} ${CClear} give the connection to recover on its own before intervening. With this value${CClear}"
  echo -e "${InvGreen} ${CClear} defaulting to 1x, if connectivity issues occur within the default 60 second Timer${CClear}"
  echo -e "${InvGreen} ${CClear} Loop, the connectivity will be reset after those 60 seconds."
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Example: 60 Second Timer Loops with 3x Recovery Timeouts would reset the connection${CClear}"
  echo -e "${InvGreen} ${CClear} after 3 minutes."
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} (Defaults: Timer Loop = 60 seconds | Recovery Timeouts = 1x)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: Timer Loop = ${CGreen}$timerloop sec ${CClear}| Recovery Timeouts: ${CGreen}${recover}x${CClear}"
  echo
  read -p "Please enter new Timer Loop value in seconds [10-999] (e=Exit): " newTimerLoop
  if [ -z "$newTimerLoop" ] || echo "$newTimerLoop" | grep -qE "^(e|E)$"
  then
      if echo "$timerloop" | grep -qE "^([1-9][0-9]{0,2})$" && \
         [ "$timerloop" -ge 10 ] && [ "$timerloop" -le 999 ]
      then
          timer="$timerloop"
          printf "\n${CClear}[Exiting]\n"
          sleep 1 ; break
      else
          printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
          sleep 3
      fi
  elif echo "$newTimerLoop" | grep -qE "^([1-9][0-9]{0,2})$" && \
       [ "$newTimerLoop" -ge 10 ] && [ "$newTimerLoop" -le 999 ]
  then
      timerloop="$newTimerLoop"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Timer Loop configuration saved" >> $logfile
      saveconfig
      timer="$timerloop"
      printf "\n${CClear}[OK]\n"
      sleep 1
  else
      printf "\n${CRed}*ERROR*: Please enter a valid number between 10 and 999.${CClear}\n"
      sleep 3
  fi

  echo ""
  read -p "Please enter new Recovery Timeout value [1-9] (e=Exit): " newRecoveryTimeout
  if [ -z "$newRecoveryTimeout" ] || echo "$newRecoveryTimeout" | grep -qE "^(e|E)$"
  then
      if echo "$recover" | grep -qE "^([1-9])$" && \
         [ "$recover" -ge 1 ] && [ "$recover" -le 9 ]
      then
          printf "\n${CClear}[Exiting]\n"
          sleep 1 ; break
      else
          printf "\n${CRed}*ERROR*: Please enter a valid number between 1 and 9.${CClear}\n"
          sleep 3
      fi
  elif echo "$newRecoveryTimeout" | grep -qE "^([1-9])$" && \
       [ "$newRecoveryTimeout" -ge 1 ] && [ "$newRecoveryTimeout" -le 9 ]
  then
      recover="$newRecoveryTimeout"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Recovery Timeout Opportunity configuration saved" >> $logfile
      saveconfig
      printf "\n${CClear}[OK]\n"
      sleep 1 ; break
  else
      printf "\n${CRed}*ERROR*: Please enter a valid number between 1 and 9.${CClear}\n"
      sleep 3
  fi
done

}

# -------------------------------------------------------------------------------------------------------------------------
# maxping lets you configure how high the vpn tunnel ping will get before it's reset

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-05] ##
##----------------------------------------##
maxping()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum Ping Before Reset                                                             ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate how high the PING can be across your VPN tunnel before resetting the${CClear}"
  echo -e "${InvGreen} ${CClear} connection in favor of a different server with a lower PING? A connection with a${CClear}"
  echo -e "${InvGreen} ${CClear} lower PING may provide better network performance and less latency.${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = 500 milliseconds, Disabled = 0)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$pingreset ms${CClear}"
  echo
  read -p "Please enter numeric value (0-999)? (0=Disabled, e=Exit): " newPingReset
  if echo "$newPingReset" | grep -qE "^(0|[1-9][0-9]{0,2})$" && \
     [ "$newPingReset" -ge 0 ] && [ "$newPingReset" -le 999 ]
  then
      pingreset="$newPingReset"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: PING Reset Configuration saved" >> $logfile
      saveconfig
  elif [ -z "$newPingReset" ] || echo "$newPingReset" | grep -qE "^(E|e)$"
  then
      echo ; echo -e "${CClear}[Exiting]"
      timer="$timerloop"
      sleep 2
      break
  else
      echo
      echo -e "${CClear}[Please enter value between 0 and 999, e=Exit]"
      sleep 3
  fi
done
}

##-------------------------------------##
## Added by Martinski W. [2024-Oct-06] ##
##-------------------------------------##
_ValidateCronJobHour_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   if echo "$1" | grep -qE "^(0|[1-9][0-9]?)$" && \
      [ "$1" -ge 0 ] && [ "$1" -lt 24 ]
   then return 0 ; else return 1 ; fi
}

_ValidateCronJobMinute_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
    if echo "$1" | grep -qE "^(0|[1-9][0-9]?)$" && \
       [ "$1" -ge 0 ] && [ "$1" -lt 60 ]
    then return 0 ; else return 1 ; fi
}

# -------------------------------------------------------------------------------------------------------------------------
# schedulevpnreset lets you enable and set a time for a scheduled daily vpn reset

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-06] ##
##----------------------------------------##
schedulevpnreset()
{

while true
do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Reset Scheduler                                                                   ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate below if you would like to enable and schedule a daily VPN Reset CRON"
  echo -e "${InvGreen} ${CClear} job. This will reset each monitored VPN connection. (Default = Disabled)"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  if [ "$schedule" = "0" ]
  then
     echo -e "${InvGreen} ${CClear} Current: ${CRed}Disabled${CClear}"
  elif [ "$schedule" = "1" ]
  then
     schedhrs="$(awk "BEGIN {printf \"%02.f\",${schedulehrs}}")"
     schedmin="$(awk "BEGIN {printf \"%02.f\",${schedulemin}}")"
     schedtime="${CGreen}$schedhrs:$schedmin${CClear}"
     echo -e "${InvGreen} ${CClear} Current: ${CGreen}Enabled, Daily @ $schedtime${CClear}"
  fi
  echo
  read -p 'Schedule Daily Reset? (0=No, 1=Yes, e=Exit): ' newSchedule
  if [ -z "$newSchedule" ] ; then newSchedule="${schedule:=0}" ; fi

  if [ "$newSchedule" = "0" ]
  then
    schedule=0
    if [ -f /jffs/scripts/services-start ]
    then
      sed -i -e '/vpnmon-r3.sh/d' /jffs/scripts/services-start
      cru d RunVPNMONR3reset
      schedulehrs=1
      schedulemin=0
      echo ""
      echo -e "${CGreen}[Modifiying SERVICES-START file]..."
      sleep 2
      echo ""
      echo -e "${CGreen}[Modifying CRON jobs]..."
      sleep 2
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Reset Schedule Disabled" >> $logfile
      saveconfig
      timer="$timerloop"
      break
    fi

  elif [ "$newSchedule" = "1" ]
  then
    schedule=1
    echo
    echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Reset Scheduler                                                                   ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} Please indicate below what time you would like to schedule a daily VPN Reset CRON"
    echo -e "${InvGreen} ${CClear} job. (Default = 1 hr, 0 min = 01:00 = 1:00am)"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo
    read -p 'Schedule HOURS [0-23]?: ' newScheduleHrs
    if [ -z "$newScheduleHrs" ]
    then
        if _ValidateCronJobHour_ "$schedulehrs"
        then scheduleHrsOK=true
        else scheduleHrsOK=false
        fi
    elif _ValidateCronJobHour_ "$newScheduleHrs"
    then
        scheduleHrsOK=true
        schedulehrs="$newScheduleHrs"
    else
        scheduleHrsOK=false
        schedulehrs="${schedulehrs:=1}"
        printf "${CRed}*ERROR*: INVALID Entry.${CClear}\n\n"
    fi
    read -p 'Schedule MINUTES [0-59]?: ' newScheduleMins
    if [ -z "$newScheduleMins" ]
    then
        if _ValidateCronJobMinute_ "$schedulemin"
        then scheduleMinsOK=true
        else scheduleMinsOK=false
        fi
    elif _ValidateCronJobMinute_ "$newScheduleMins"
    then
        scheduleMinsOK=true
        schedulemin="$newScheduleMins"
    else
        scheduleMinsOK=false
        schedulemin="${schedulemin:=0}"
        printf "${CRed}*ERROR*: INVALID Entry.${CClear}\n"
    fi
    if ! "$scheduleHrsOK" || ! "$scheduleMinsOK"
    then
        doResetSave=false
        if ! "$scheduleHrsOK" && ! _ValidateCronJobHour_ "$schedulehrs"
        then schedulehrs=1 ; doResetSave=true
        fi
        if ! "$scheduleMinsOK" && ! _ValidateCronJobMinute_ "$schedulemin"
        then schedulemin=0 ; doResetSave=true
        fi
        if "$doResetSave"
        then
            schedule=0
            saveconfig
            printf "\n${CRed}INVALID input found. Resetting values.${CClear}\n\n"
        else
            printf "\n${CRed}INVALID input found. No changes made.${CClear}\n\n"
        fi
        echo -e "${CClear}[Exiting]"
        timer="$timerloop"
        sleep 3
        break
    fi
    echo
    echo -e "${CGreen}[Modifying SERVICES-START file]..."
    sleep 2

    if [ -f /jffs/scripts/services-start ]
    then
      if ! grep -q -F "sh /jffs/scripts/vpnmon-r3.sh -reset" /jffs/scripts/services-start
      then
        echo 'cru a RunVPNMONR3reset "'"$schedulemin $schedulehrs * * * sh /jffs/scripts/vpnmon-r3.sh -reset"'"' >> /jffs/scripts/services-start
        cru a RunVPNMONR3reset "$schedulemin $schedulehrs * * * sh /jffs/scripts/vpnmon-r3.sh -reset"
      else
        #delete and re-add if it already exists in case there's a time change
        sed -i -e '/vpnmon-r3.sh/d' /jffs/scripts/services-start
        cru d RunVPNMONR3reset
        echo 'cru a RunVPNMONR3reset "'"$schedulemin $schedulehrs * * * sh /jffs/scripts/vpnmon-r3.sh -reset"'"' >> /jffs/scripts/services-start
        cru a RunVPNMONR3reset "$schedulemin $schedulehrs * * * sh /jffs/scripts/vpnmon-r3.sh -reset"
      fi
    else
      echo 'cru a RunVPNMONR3reset "'"$schedulemin $schedulehrs * * * sh /jffs/scripts/vpnmon-r3.sh -reset"'"' >> /jffs/scripts/services-start
      chmod 755 /jffs/scripts/services-start
      cru a RunVPNMONR3reset "$schedulemin $schedulehrs * * * sh /jffs/scripts/vpnmon-r3.sh -reset"
    fi

    echo
    echo -e "${CGreen}[Modifying CRON jobs]..."
    sleep 2
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Reset Schedule Enabled" >> $logfile
    saveconfig
    timer="$timerloop"
    break

  elif [ "$newSchedule" = "e" ]
  then
     echo ; echo -e "${CClear}[Exiting]"
     timer="$timerloop"
     sleep 2
     break
  else
     schedule="${schedule:=0}"
     schedulehrs="${schedulehrs:=1}"
     schedulemin="${schedulemin:=0}"
     saveconfig
  fi

done
}

# -------------------------------------------------------------------------------------------------------------------------
# autostart lets you enable the ability for vpnmon-r3 to autostart after a router reboot

autostart()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Reboot Protection                                                                     ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate below if you would like to enable VPNMON-R3 to autostart after a"
  echo -e "${InvGreen} ${CClear} router reboot. This will ensure continued, uninterrupted VPN connection monitoring."
  echo -e "${InvGreen} ${CClear} (Default = Disabled)"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  if [ "$autostart" = "0" ]
  then
     echo -e "${InvGreen} ${CClear} Current: ${CRed}Disabled${CClear}"
  elif [ "$autostart" = "1" ]
  then
     echo -e "${InvGreen} ${CClear} Current: ${CGreen}Enabled${CClear}"
  fi
  echo
  read -p 'Enable Reboot Protection? (0=No, 1=Yes, e=Exit): ' newAutoStart
  # Use default value on enter keypress or invalid input #
  if [ -z "$newAutoStart" ] ; then newAutoStart="${autostart:=0}" ; fi

  if [ "$newAutoStart" = "0" ]
  then
    autostart=0
    if [ -f /jffs/scripts/post-mount ]
    then
      sed -i -e '/vpnmon-r3.sh/d' /jffs/scripts/post-mount
      echo ""
      echo -e "${CGreen}[Modifying POST-MOUNT file]..."
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Reboot Protection Disabled" >> $logfile
      saveconfig
      sleep 2
      timer="$timerloop"
      break
    fi

  elif [ "$newAutoStart" = "1" ]
  then
    autostart=1
    if [ -f /jffs/scripts/post-mount ]
    then
      if ! grep -q -F "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" /jffs/scripts/post-mount
      then
        echo "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" >> /jffs/scripts/post-mount
        echo
        echo -e "${CGreen}[Modifying POST-MOUNT file]..."
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Reboot Protection Enabled" >> $logfile
        saveconfig
        sleep 2
        timer="$timerloop"
        break
      else
        saveconfig
        sleep 1
      fi

    else
      echo "#!/bin/sh" > /jffs/scripts/post-mount
      echo "" >> /jffs/scripts/post-mount
      echo "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" >> /jffs/scripts/post-mount
      chmod 755 /jffs/scripts/post-mount
      echo
      echo -e "${CGreen}[Modifying POST-MOUNT file]..."
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Reboot Protection Enabled" >> $logfile
      saveconfig
      sleep 2
      timer="$timerloop"
      break
    fi

  elif [ "$newAutoStart" = "e" ]
  then
     echo ; echo -e "${CClear}[Exiting]"
     timer="$timerloop"
     sleep 2
     break
  else
     autostart="${autostart:=0}"
     saveconfig
  fi

done
}

# -------------------------------------------------------------------------------------------------------------------------
# trimlogs will cut down log size (in rows) based on custom value

trimlogs()
{
  if [ "$logsize" -gt 0 ]
  then
      currlogsize="$(wc -l "$logfile" | awk '{ print $1 }')" # Determine the number of rows in the log

      if [ "$currlogsize" -gt "$logsize" ] # If it's bigger than the max allowed, tail/trim it!
      then
          tail -"$logsize" "$logfile" > "${logfile}.tmp"
          mv "${logfile}.tmp" "$logfile"
          echo "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Trimmed the log file down to $logsize lines" >> "$logfile"
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# saveconfig saves the vpnmon-r3.cfg file after every major change, and applies that to the script on the fly

saveconfig()
{
   { echo 'availableslots="'"$availableslots"'"'
     echo 'PINGHOST="'"$PINGHOST"'"'
     echo 'PINGHOST2="'"$PINGHOST2"'"'
     echo 'logsize='$logsize
     echo 'timerloop='$timerloop
     echo 'recover='$recover
     echo 'schedule='$schedule
     echo 'schedulehrs='$schedulehrs
     echo 'schedulemin='$schedulemin
     echo 'autostart='$autostart
     echo 'pingreset='$pingreset
     echo 'automation1="'"$automation1"'"'
     echo 'automation2="'"$automation2"'"'
     echo 'automation3="'"$automation3"'"'
     echo 'automation4="'"$automation4"'"'
     echo 'automation5="'"$automation5"'"'
     echo 'wgautomation1="'"$wgautomation1"'"'
     echo 'wgautomation2="'"$wgautomation2"'"'
     echo 'wgautomation3="'"$wgautomation3"'"'
     echo 'wgautomation4="'"$wgautomation4"'"'
     echo 'wgautomation5="'"$wgautomation5"'"'
     echo 'refreshserverlists='$refreshserverlists
     echo 'unboundclient='$unboundclient
     echo 'unboundwgclient='$unboundwgclient
     echo 'unboundshowip='$unboundshowip
     echo 'monitorwan='$monitorwan
     echo 'useovpn='$useovpn
     echo 'usewg='$usewg
     echo 'updateskynet='$updateskynet
     echo 'amtmemailsuccess='$amtmemailsuccess
     echo 'amtmemailfailure='$amtmemailfailure
     echo 'rstspdmerlin='$rstspdmerlin
     echo 'ratelimit='$ratelimit
     echo 'selectionmethod='$selectionmethod
     echo 'lowutilspd='$lowutilspd
     echo 'medutilspd='$medutilspd
     echo 'lowutilspdup='$lowutilspdup
     echo 'medutilspdup='$medutilspdup
     echo 'bwdisp='$bwdisp
     echo 'recoverytimer='$recoverytimer
     echo 'wandowntimer='$wandowntimer
     echo 'reconnecttimer='$reconnecttimer
   } > "$config"

   echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New vpnmon-r3.cfg File Saved" >> $logfile

   if [ -f "$config" ]
     then
       source "$config"
   fi

   dvpn_loadconfig
   dvpn_check_and_apply
}

# -------------------------------------------------------------------------------------------------------------------------
# VPN_GetClientState was created by @Martinski in many thanks to trying to eliminate unknown operand errors due to null
# vpn_clientX_state values

_VPN_GetClientState_()
{
    if [ $# -lt 1 ] || [ -z "$1" ] || ! echo "$1" | grep -qE "^[1-5]$"
    then echo "**ERROR**" ; return 1 ; fi

    local nvramVal="$($timeoutcmd$timeoutsec nvram get "vpn_client${1}_state")"
    if [ -z "$nvramVal" ] || ! echo "$nvramVal" | grep -qE "^[+-]?[0-9]$"
    then echo "0" ; else echo "$nvramVal" ; fi
    return 0
}

# -------------------------------------------------------------------------------------------------------------------------
# WG_GetClientState is based off _VPN_GetClientState_

_WG_GetClientState_()
{
    if [ $# -lt 1 ] || [ -z "$1" ] || ! echo "$1" | grep -qE "^[1-5]$"
    then echo "**ERROR**" ; return 1 ; fi

    # Inspiration from ZebMcKayHan's WGC Watchdog Script
    last_handshake=$(wg show wgc$1 latest-handshakes | awk '{print $2}') >/dev/null 2>&1

    if [ -z $last_handshake ]
      then
        WGnvramVal=0 #disconnected
      else
        WGnvramVal=2 #connected
    fi

    #local WGnvramVal="$($timeoutcmd$timeoutsec nvram get "wgc${1}_enable")"
    if [ -z "$WGnvramVal" ] || ! echo "$WGnvramVal" | grep -qE "^[+-]?[0-9]$"
    then echo "0" ; else echo "$WGnvramVal" ; fi
    return 0
}

# -------------------------------------------------------------------------------------------------------------------------

########################################################################
# AMTM Email Notification Functionality generously donated by @Martinski!
#
# Creation Date: 2020-Jun-11 [Martinski W.]
# Last Modified: 2024-Feb-07 [Martinski W.]
# Modified for VPNMON-R3 Purposes [Viktor Jaep]
########################################################################

#-----------------------------------------------------------#
_DownloadCEMLibraryFile_()
{
   local msgStr  retCode
   case "$1" in
        update) msgStr="Updating" ;;
       install) msgStr="Installing" ;;
             *) return 1 ;;
   esac

   printf "\33[2K\r"
   printf "${CGreen}\r[INFO: ${msgStr} the shared AMTM email library script file to support email notifications...]${CClear}"
   echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: ${msgStr} the shared AMTM email library script file to support email notifications..." >> $logfile

   mkdir -m 755 -p "$CUSTOM_EMAIL_LIBDir"
   curl -kLSs --retry 3 --retry-delay 5 --retry-connrefused \
   "${CEM_LIB_URL}/$CUSTOM_EMAIL_LIBName" -o "$CUSTOM_EMAIL_LIBFile"
   curlCode="$?"

   if [ "$curlCode" -eq 0 ] && [ -f "$CUSTOM_EMAIL_LIBFile" ]
   then
       retCode=0
       chmod 755 "$CUSTOM_EMAIL_LIBFile"
       . "$CUSTOM_EMAIL_LIBFile"
       #printf "\nDone.\n"
   else
       retCode=1
       printf "\33[2K\r"
       printf "${CRed}\r[ERROR: Unable to download the shared library script file ($CUSTOM_EMAIL_LIBName).]${CClear}"
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - **ERROR**: Unable to download the shared AMTM email library script file [$CUSTOM_EMAIL_LIBName]." >> $logfile
   fi
   return "$retCode"
}

#-----------------------------------------------------------#
# ARG1: The email name/alias to be used as "FROM_NAME"
# ARG2: The email Subject string.
# ARG3: Full path of file containing the email Body text.
# ARG4: The email Body Title string [OPTIONAL].
#-----------------------------------------------------------#
_SendEMailNotification_()
{
   if [ -z "${amtmIsEMailConfigFileEnabled:+xSETx}" ]
   then
       printf "\33[2K\r"
       printf "${CRed}\r[ERROR: Email library script ($CUSTOM_EMAIL_LIBFile) *NOT* FOUND.]${CClear}"
       sleep 5
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - **ERROR**: Email library script [$CUSTOM_EMAIL_LIBFile] *NOT* FOUND." >> $logfile
       return 1
   fi

   if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
   then
       printf "\33[2K\r"
       printf "${CRed}\r[ERROR: INSUFFICIENT email parameters]${CClear}"
       sleep 5
       echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - **ERROR**: INSUFFICIENT email parameters." >> $logfile
       return 1
   fi
   local retCode  emailBodyTitleStr=""

   [ $# -gt 3 ] && [ -n "$4" ] && emailBodyTitleStr="$4"

   FROM_NAME="$1"
   _SendEMailNotification_CEM_ "$2" "-F=$3" "$emailBodyTitleStr"
   retCode="$?"

   if [ "$retCode" -eq 0 ]
   then
      printf "\33[2K\r"
      printf "${CGreen}\r[Email notification was sent successfully ($2)]${CClear}"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Email notification was sent successfully [$2]" >> $logfile
      sleep 5
   else
      printf "\33[2K\r"
      printf "${CRed}\r[ERROR: Failure to send email notification (Error Code: $retCode - $2).]${CClear}"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - **ERROR**: Failure to send email notification [$2]" >> $logfile
      sleep 5
   fi

   return "$retCode"
}

# -------------------------------------------------------------------------------------------------------------------------
# sendmessage is a function that sends an AMTM email based on activity within VPNMON-R3
# $1 = Success/Failure 0/1
# $2 = Component
# $3 = VPN Slot

sendmessage()
{

  #If AMTM email functionality is disabled, return back to the function call
  if [ "$amtmemailsuccess" = "0" ] && [ "$amtmemailfailure" = "0" ]; then
     return
  fi

  #Load, install or update the shared AMTM Email integration library
  if [ -f "$CUSTOM_EMAIL_LIBFile" ]
  then
    . "$CUSTOM_EMAIL_LIBFile"

    if [ -z "${CEM_LIB_VERSION:+xSETx}" ] || \
       _CheckLibraryUpdates_CEM_ "$CUSTOM_EMAIL_LIBDir" quiet
    then
       _DownloadCEMLibraryFile_ "update"
    fi
  else
      _DownloadCEMLibraryFile_ "install"
  fi

  cemIsFormatHTML=true
  cemIsVerboseMode=false
  tmpEMailBodyFile="/tmp/var/tmp/tmpEMailBody_${scriptFileNTag}.$$.TXT"

  ratelimiter
  emaillimit="$?"
  if [ "$emaillimit" -eq 0 ]
    then

      #Pick the scenario and send email
      if [ "$1" = "1" ] && [ "$amtmemailfailure" = "1" ]; then
        if [ "$2" = "Recovering from WAN Down" ]; then
          emailSubject="ALERT: Router Recovering from WAN Down"
          emailBodyTitle="ALERT: Router Recovering from WAN Down"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>ALERT: VPNMON-R3</b> is currently recovering from a WAN Down Situation!\n"
          printf "Router has detected a WAN Link/Modem and waited 300 seconds for general network.\n"
          printf "connectivity to stabilize before re-establishing VPN connectivity.\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Slot In Error State" ]; then
          emailSubject="FAILURE: VPN Slot $3 in Error State"
          emailBodyTitle="FAILURE: VPN Slot $3 in Error State"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>FAILURE: VPNMON-R3</b> has detected that VPN Slot $3 is in an error state. VPN Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Tunnel Disconnected" ]; then
          emailSubject="FAILURE: VPN Slot $3 has Disconnected"
          emailBodyTitle="FAILURE: VPN Slot $3 has Disconnected"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>FAILURE: VPNMON-R3</b> has detected that VPN Slot $3 has disconnected. VPN Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Slot Is Non-Responsive" ]; then
          emailSubject="FAILURE: VPN Slot $3 is Non-Responsive"
          emailBodyTitle="FAILURE: VPN Slot $3 is Non-Responsive"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>FAILURE: VPNMON-R3</b> has detected that VPN Slot $3 is non-responsive. VPN Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Slot Exceeded Max Ping" ]; then
          emailSubject="WARNING: VPN Slot $3 Exceeded Max Ping"
          emailBodyTitle="WARNING: VPN Slot $3 Exceeded Max Ping"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that VPN Slot $3 exceeded max ping. VPN Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Slot Not Synced With Unbound" ]; then
          emailSubject="WARNING: VPN Slot $3 Not Synced with Unbound"
          emailBodyTitle="WARNING: VPN Slot $3 Not Synced with Unbound"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that VPN Slot $3 is not synced with Unbound. VPN Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Slot Not Synced With Unbound" ]; then
          emailSubject="WARNING: WG Slot $3 Not Synced with Unbound"
          emailBodyTitle="WARNING: WG Slot $3 Not Synced with Unbound"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that WG Slot $3 is not synced with Unbound. WG Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        ##-------------------------------------##
        ## Modified by Dan G. [2025-Jul-16]    ##
        ##-------------------------------------##
        elif [ "$2" = "VPN Server List Query Yielded 0 Rows" ]; then
          emailSubject="WARNING: VPN Slot $3 Server List Query Yielded 0 Rows"
          emailBodyTitle="WARNING: VPN Slot $3 Server List Query Yielded 0 Rows"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that the Custom Server List Query for VPN Slot $3 yielded 0 results.\n"
          printf "This may be due to an error in the query, or the VPN provider API service may be down or unreachable."
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Server List Query Yielded 0 Rows" ]; then
          emailSubject="WARNING: WG Slot $3 Server List Query Yielded 0 Rows"
          emailBodyTitle="WARNING: WG Slot $3 Server List Query Yielded 0 Rows"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that the Custom Server List Query for WG Slot $3 yielded 0 results.\n"
          printf "This may be due to an error in the query, or the VPN provider API service may be down or unreachable."
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Slot Exceeded Max Ping" ]; then
          emailSubject="WARNING: WG Slot $3 Exceeded Max Ping"
          emailBodyTitle="WARNING: WG Slot $3 Exceeded Max Ping"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that WG Slot $3 exceeded max ping. WG Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Handshake Exceeded" ]; then
          emailSubject="WARNING: WG Slot $3 Exceeded Handshake"
          emailBodyTitle="WARNING: WG Slot $3 Exceeded Handshake"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that WG Slot $3 exceeded a 180s handshake. WG Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Tunnel Disconnected" ]; then
          emailSubject="WARNING: WG Slot $3 Tunnel Disconnected"
          emailBodyTitle="WARNING: WG Slot $3 Tunnel Disconnected"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that WG Slot $3 tunnel disconnected. WG Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Slot Is Non-Responsive" ]; then
          emailSubject="WARNING: WG Slot $3 is Non-Responsive"
          emailBodyTitle="WARNING: WG Slot $3 is Non-Responsive"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>WARNING: VPNMON-R3</b> has detected that WG Slot $3 is not responding. WG Slot $3 has been reset.\n"
          printf "Please check your network environment and configuration if this error continues to persist."
          printf "\n"
          } > "$tmpEMailBodyFile"
        fi
        _SendEMailNotification_ "VPNMON-R3 v$version" "$emailSubject" "$tmpEMailBodyFile" "$emailBodyTitle"
      fi

      if [ "$1" = "0" ] && [ "$amtmemailsuccess" = "1" ]; then
        if [ "$2" = "VPN Connection Scheduled Reset" ]; then
          emailSubject="SUCCESS: VPN Slot $3 Manual/Scheduled Reset"
          emailBodyTitle="SUCCESS: VPN Slot $3 Manual/Scheduled Reset"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>SUCCESS: VPNMON-R3</b> completed a successful manual/scheduled reset on VPN Slot $3\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Reset" ]; then
          emailSubject="SUCCESS: VPN Slot $3 Manual Reset"
          emailBodyTitle="SUCCESS: VPN Slot $3 Manual Reset"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>SUCCESS: VPNMON-R3</b> completed a successful manual reset on VPN Slot $3\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "VPN Killed" ]; then
          emailSubject="SUCCESS: VPN Slot $3 Manually Stopped & Unmonitored"
          emailBodyTitle="SUCCESS: VPN Slot $3 Manually Stopped & Unmonitored"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>SUCCESS: VPNMON-R3</b> successfully manually stopped and unmonitored VPN Slot $3\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        ##-------------------------------------##
        ## Added by Dan G. [2025-Jul-16]       ##
        ##-------------------------------------##
        elif [ "$2" = "WG Connection Scheduled Reset" ]; then
          emailSubject="SUCCESS: WG Slot $3 Manual/Scheduled Reset"
          emailBodyTitle="SUCCESS: WG Slot $3 Manual/Scheduled Reset"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>SUCCESS: VPNMON-R3</b> completed a successful manual/scheduled reset on WG Slot $3\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Reset" ]; then
          emailSubject="SUCCESS: WG Slot $3 Manual Reset"
          emailBodyTitle="SUCCESS: WG Slot $3 Manual Reset"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>SUCCESS: VPNMON-R3</b> completed a successful manual reset on WG Slot $3\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        elif [ "$2" = "WG Killed" ]; then
          emailSubject="SUCCESS: WG Slot $3 Manually Stopped & Unmonitored"
          emailBodyTitle="SUCCESS: WG Slot $3 Manually Stopped & Unmonitored"
          {
          printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
          printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
          printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
          printf "\n"
          printf "<b>SUCCESS: VPNMON-R3</b> successfully manually stopped and unmonitored WG Slot $3\n"
          printf "\n"
          } > "$tmpEMailBodyFile"
        fi
        _SendEMailNotification_ "VPNMON-R3 v$version" "$emailSubject" "$tmpEMailBodyFile" "$emailBodyTitle"
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Function to keep track of emails sent, and determine if they need to be rate-limited
ratelimiter()
{

#if rate limiting is disabled, exit right away
if [ "$ratelimit" = "0" ]; then
  return 0
fi

#Make sure log file exists
touch "$vr3emails"

#check current time and 1h into the past
current_time=$(date +%s)
cutoff_time=$((current_time - 3600))

#create a temp file where current data will get moved over into that is less than 1hr old
vr3emailstemp="${vr3emails}.tmp"
awk -v cutoff="$cutoff_time" '$1 > cutoff' "$vr3emails" > "$vr3emailstemp"

#check to see how many emails have been sent in the last hour
recent_email_count=$(wc -l < "$vr3emailstemp" | tr -d ' ')

printf "\33[2K\r"
printf "${CGreen}\r[Checking email rate limit... $recent_email_count/$ratelimit emails sent within the last hour]"
sleep 2

#logic to determine if rate limit has been hit
if [ "$recent_email_count" -ge "$ratelimit" ]
  then
    printf "\33[2K\r"
    printf "${CGreen}\r[Rate limit exceeded. Emails will be prevented from sending]"
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Email Rate limit exceeded ($ratelimit). Emails will be prevented from sending." >> $logfile
    sleep 2
    mv "$vr3emailstemp" "$vr3emails"
    return 1
  else
    printf "\33[2K\r"
    printf "${CGreen}\r[Rate within limits. Proceeding to send email]"
    sleep 1
    echo "$current_time" >> "$vr3emailstemp"
    mv "$vr3emailstemp" "$vr3emails"
    return 0
fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Testing to see if VPNMON-R3 external reset is currently running, and if so, hold off until it finishes
lockcheck()
{

  while [ -f "$lockfile" ]; do
    clear
    echo -e "${InvGreen} ${InvDkGray}${CWhite} External VPN Reset Currently In-Progress                                              ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} VPNMON-R3 is currently performing an external scheduled reset of the VPN through${CClear}"
    echo -e "${InvGreen} ${CClear} the means of the '-reset' commandline option, or scheduled CRON job.${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} [Retrying to resume normal operations every 15 seconds]${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    spinner 15
    lockactive=1
  done

  if [ "$lockactive" = "1" ]; then
    timerreset=1
    lockactive=0
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Initiate a VPN restart - $1 = slot number

restartvpn()
{

  echo -e "${CGreen}\nMessages:                           ${CClear}"
  echo ""

  #Check the current connection state of vpn slot
  currvpnstate="$(_VPN_GetClientState_ "$1")"

  if [ "$currvpnstate" -ne 0 ]; then
    printf "${CGreen}\r[Stopping VPN Client $1]"
    service stop_vpnclient$1 >/dev/null 2>&1
    sleep 10
    if [ "$currvpnstate" = "-1" ]; then
      nvram set vpn_client$1_state=0
    fi
    printf "\33[2K\r"
  fi

  #Determine how many server entries are in the assigned vpn slot alternate servers file
  if [ -f "/jffs/addons/vpnmon-r3.d/vr3svr$1.txt" ]
  then
    servers=$(cat "/jffs/addons/vpnmon-r3.d/vr3svr$1.txt" | wc -l) >/dev/null 2>&1
    if [ -z "$servers" ] || [ "$servers" -eq 0 ]
    then
      #Restart the same server currently allocated to that vpn slot
      currvpnhost=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
      printf "\33[2K\r"
      printf "${CGreen}\r[Starting VPN Client $1]"
      service start_vpnclient$1 >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - Current Server: $currvpnhost" >> $logfile
      resettimer $1 "VPN"
      sleep 5
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting VPN$1 Settle]"
      sleep 5
      return

    elif [ "$selectionmethod" -eq 1 ] # 1=roundrobin
      then
        robintracker="/jffs/addons/vpnmon-r3.d/vr3robin.txt"

        # If the robintracker file doesn't exist, create it and start all from 0.
        if [ ! -f "$robintracker" ]; then
          { echo 'VPN1RR=0'
            echo 'VPN2RR=0'
            echo 'VPN3RR=0'
            echo 'VPN4RR=0'
            echo 'VPN5RR=0'
            echo 'WG1RR=0'
            echo 'WG2RR=0'
            echo 'WG3RR=0'
            echo 'WG4RR=0'
            echo 'WG5RR=0'
          } > "$robintracker"

          printf "\33[2K\r"
          printf "${CGreen}\r[Writing New Sequential Tracker File]"
          sleep 1
        fi

        # Read the last used line number from the tracker file, calculate next
        lastused=$(grep 'VPN'$1'RR=' "$robintracker" | cut -d'=' -f2)
        nextup="$((lastused+1))"

        # Check if we've reached the end of the file. If so, loop back to line 1.
        if [ "$nextup" -gt "$servers" ]; then
          nextup=1
        fi

        printf "\33[2K\r"
        printf "${CGreen}\r[Selecting Next Sequential Entry]"

        #---------OVPN-specific nvram values

        # Extract the target line and parse it
        RNDVPNIP=$(sed -n "${nextup}p" /jffs/addons/vpnmon-r3.d/vr3svr$1.txt)
        nvram set vpn_client"$1"_addr="$RNDVPNIP"
        nvram set vpn_client"$1"_desc="VPN$1 - $RNDVPNIP added by VPNMON-R3"
        sleep 1

        #---------OVPN-specific nvram values

        # Update the tracker file with the line number we just used.
        sed -i "s/^VPN$1RR=.*/VPN$1RR=$nextup/" "$robintracker"

        #Restart the new server currently allocated to that vpn slot
        printf "\33[2K\r"
        printf "${CGreen}\r[Starting VPN Client $1]"
        service start_vpnclient$1 >/dev/null 2>&1
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted [SEQ] - New Server: $RNDVPNIP" >> $logfile
        resettimer $1 "VPN"
        sleep 5
        printf "\33[2K\r"
        printf "${CGreen}\r[Letting VPN$1 Settle]"
        sleep 5

    elif [ "$selectionmethod" -eq 0 ] # 0=Random
      then
        #Pick a random server from the alternate servers file, populate in vpn client slot, and restart
        printf "\33[2K\r"
        printf "${CGreen}\r[Selecting Random Entry]"
        RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
        R_LINE=$(( RANDOM % servers + 1 ))

        #---------OVPN-specific nvram values

        RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/addons/vpnmon-r3.d/vr3svr$1.txt)
        nvram set vpn_client"$1"_addr="$RNDVPNIP"
        nvram set vpn_client"$1"_desc="VPN$1 - $RNDVPNIP added by VPNMON-R3"
        sleep 1

        #---------OVPN-specific nvram values

        #Restart the new server currently allocated to that vpn slot
        printf "\33[2K\r"
        printf "${CGreen}\r[Starting VPN Client $1]"
        service start_vpnclient$1 >/dev/null 2>&1
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted [RND] - New Server: $RNDVPNIP" >> $logfile
        resettimer $1 "VPN"
        sleep 5
        printf "\33[2K\r"
        printf "${CGreen}\r[Letting VPN$1 Settle]"
        sleep 5
    fi

  else
    #Restart the same server currently allocated to that vpn slot
    printf "\33[2K\r"
    printf "${CGreen}\r[Starting VPN Client $1]"
    currvpnhost="$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)"
    service start_vpnclient$1 >/dev/null 2>&1
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - Current Server: $currvpnhost" >> $logfile
    resettimer $1 "VPN"
    sleep 5
    printf "\33[2K\r"
    printf "${CGreen}\r[Letting VPN$1 Settle]"
    sleep 5
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Initiate a WG restart - $1 = slot number

restartwg()
{

  echo -e "${CGreen}\nMessages:                           ${CClear}"
  echo ""

  #Check the current connection state of vpn slot
  currwgstate="$(_WG_GetClientState_ $1)"

  if [ "$currwgstate" -ne 0 ]; then
    printf "${CGreen}\r[Stopping WG Client $1]"
    service "stop_wgc $1" >/dev/null 2>&1
    sleep 10
    printf "\33[2K\r"
  fi

  #Determine how many server entries are in the assigned vpn slot alternate servers file
  if [ -f "/jffs/addons/vpnmon-r3.d/vr3wgsvr$1.txt" ]
  then
    servers=$(cat "/jffs/addons/vpnmon-r3.d/vr3wgsvr$1.txt" | wc -l) >/dev/null 2>&1
    if [ -z "$servers" ] || [ "$servers" -eq 0 ]
    then
      #Restart the same server currently allocated to that wg slot
      currwghost="$($timeoutcmd$timeoutsec nvram get wgc$1_ep_addr)"
      currwghostname="$($timeoutcmd$timeoutsec nvram get wgc$1_desc)"
      printf "\33[2K\r"
      printf "${CGreen}\r[Starting WG Client $1]"
      service "start_wgc $1" >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WGC$1 Connection Restarted - Current Server: $currwghostname | $currwghost" >> $logfile
      resettimer $1 "WG"
      sleep 5
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting WGC$1 Settle]"
      sleep 5
      return

    elif [ "$selectionmethod" -eq 1 ] # 1=roundrobin
      then
        robintracker="/jffs/addons/vpnmon-r3.d/vr3robin.txt"

        # If the robintracker file doesn't exist, create it and start from 0.
        if [ ! -f "$robintracker" ]; then
          { echo 'VPN1RR=0'
            echo 'VPN2RR=0'
            echo 'VPN3RR=0'
            echo 'VPN4RR=0'
            echo 'VPN5RR=0'
            echo 'WG1RR=0'
            echo 'WG2RR=0'
            echo 'WG3RR=0'
            echo 'WG4RR=0'
            echo 'WG5RR=0'
          } > "$robintracker"

          printf "\33[2K\r"
          printf "${CGreen}\r[Writing New Round-Robin Tracker File]"
          sleep 1
        fi

        # Read the last used line number from the tracker file, calculate next
        lastused=$(grep 'WG'$1'RR=' "$robintracker" | cut -d'=' -f2)
        nextup="$((lastused+1))"

        # Check if we've reached the end of the file. If so, loop back to line 1.
        if [ "$nextup" -gt "$servers" ]; then
          nextup=1
        fi

        printf "\33[2K\r"
        printf "${CGreen}\r[Selecting Next Sequential Entry]"

        #---------WG-specific nvram values

        # Extract the target line and parse it
        WGLINE=$(sed -n "${nextup}p" /jffs/addons/vpnmon-r3.d/vr3wgsvr$1.txt)
        wgdescription=$(echo "$WGLINE" | cut -d ',' -f 1)
        interfaceip=$(echo "$WGLINE" | cut -d ',' -f 2)
        endpointip=$(echo "$WGLINE" | cut -d ',' -f 3)
        endpointport=$(echo "$WGLINE" | cut -d ',' -f 4)
        privatekey=$(echo "$WGLINE" | cut -d ',' -f 5)
        publickey=$(echo "$WGLINE" | cut -d ',' -f 6)
        presharedkey=$(echo "$WGLINE" | cut -d ',' -f 7) #Optional, required by AirVPN
        nvram set wgc"$1"_desc="$wgdescription"
        nvram set wgc"$1"_addr="$interfaceip"
        nvram set wgc"$1"_ep_addr="$endpointip"
        nvram set wgc"$1"_ep_addr_r="$endpointip"
        nvram set wgc"$1"_ep_port="$endpointport"
        nvram set wgc"$1"_priv="${privatekey}"
        nvram set wgc"$1"_ppub="${publickey}"
        nvram set wgc"$1"_psk="${presharedkey}" #Optional, required by AirVPN
        sleep 1

        #---------WG-specific nvram values

        # Update the tracker file with the line number we just used.
        sed -i "s/^WG$1RR=.*/WG$1RR=$nextup/" "$robintracker"

        #Restart the new server currently allocated to that wg slot
        printf "\33[2K\r"
        printf "${CGreen}\r[Starting WG Client $1]"
        service "start_wgc $1" >/dev/null 2>&1
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WGC$1 Connection Restarted [SEQ] - New Server: $wgdescription | $endpointip" >> $logfile
        resettimer $1 "WG"
        sleep 5
        printf "\33[2K\r"
        printf "${CGreen}\r[Letting WGC$1 Settle]"
        sleep 5

    elif [ "$selectionmethod" -eq 0 ] # 0=random
      then

        # Pick a random server from the alternate servers file, populate in wg client slot, and restart
        printf "\33[2K\r"
        printf "${CGreen}\r[Selecting Random Entry]"
        RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
        R_LINE=$(( RANDOM % servers + 1 ))

        #---------WG-specific nvram values

        WGLINE=$(sed -n "${R_LINE}p" /jffs/addons/vpnmon-r3.d/vr3wgsvr$1.txt)
        wgdescription=$(echo "$WGLINE" | cut -d ',' -f 1)
        interfaceip=$(echo "$WGLINE" | cut -d ',' -f 2)
        endpointip=$(echo "$WGLINE" | cut -d ',' -f 3)
        endpointport=$(echo "$WGLINE" | cut -d ',' -f 4)
        privatekey=$(echo "$WGLINE" | cut -d ',' -f 5)
        publickey=$(echo "$WGLINE" | cut -d ',' -f 6)
        presharedkey=$(echo "$WGLINE" | cut -d ',' -f 7) #Optional, required by AirVPN
        nvram set wgc"$1"_desc="$wgdescription"
        nvram set wgc"$1"_addr="$interfaceip"
        nvram set wgc"$1"_ep_addr="$endpointip"
        nvram set wgc"$1"_ep_addr_r="$endpointip"
        nvram set wgc"$1"_ep_port="$endpointport"
        nvram set wgc"$1"_priv="${privatekey}"
        nvram set wgc"$1"_ppub="${publickey}"
        nvram set wgc"$1"_psk="${presharedkey}" #Optional, required by AirVPN
        sleep 1

        #---------WG-specific nvram values

        # Restart the new server currently allocated to that wg slot
        printf "\33[2K\r"
        printf "${CGreen}\r[Starting WG Client $1]"
        service "start_wgc $1" >/dev/null 2>&1
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WGC$1 Connection Restarted [RND] - New Server: $wgdescription | $endpointip" >> $logfile
        resettimer $1 "WG"
        sleep 5
        printf "\33[2K\r"
        printf "${CGreen}\r[Letting WGC$1 Settle]"
        sleep 5
    fi

  else
    #Restart the same server currently allocated to that wg slot
    printf "\33[2K\r"
    printf "${CGreen}\r[Starting WG Client $1]"
    currwghost="$($timeoutcmd$timeoutsec nvram get wgc$1_ep_addr)"
    service "start_wgc $1" >/dev/null 2>&1
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WGC$1 Connection Restarted - Current Server: $currwghost" >> $logfile
    resettimer $1 "WG"
    sleep 5
    printf "\33[2K\r"
    printf "${CGreen}\r[Letting WGC$1 Settle]"
    sleep 5
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Separating off the vpnrouting service restart

restartrouting()
{

  printf "\33[2K\r"
  printf "${CGreen}\r[Restarting VPN Routing]"
  service restart_vpnrouting0 >/dev/null 2>&1
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Director Routing Service Restarted" >> $logfile
  sleep 5
  printf "\33[2K\r"
  trimlogs

}

# -------------------------------------------------------------------------------------------------------------------------
# Optionally reset spdMerlin interfaces
resetspdmerlin()
{

  if [ "$rstspdmerlin" = "1" ]
  then
    printf "\33[2K\r"
    printf "${CGreen}\r[Reset spdMerlin Interfaces]"
    /jffs/scripts/spdmerlin reset_interfaces force >/dev/null 2>&1
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: spdMerlin Interfaces Reset" >> $logfile
    sleep 5
    printf "\33[2K\r"
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Kill a vpn connnection, and unmonitor it - $1 = slot number

killunmonvpn()
{

  # Stop the service
  echo -e "${CGreen}\nMessages:                           ${CClear}"
  echo ""
  printf "${CGreen}\r[Stopping VPN Client $1]"
  service stop_vpnclient$1 >/dev/null 2>&1
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 has been stopped and no longer being monitored" >> $logfile
  sleep 10
  printf "\33[2K\r"
  printf "${CGreen}\r[Unmonitoring VPN Client $1]"

  # Write the VPN client file back with the correct monitoring configuration
  sed -i "s/^VPN$1=.*/VPN$1=0/" "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
  sed -i "s/^VPNTIMER$1=.*/VPNTIMER$1=0/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  sleep 5

  # Restart VPN Director Routing Services
  restartrouting

}

# -------------------------------------------------------------------------------------------------------------------------
# Kill a wg connnection, and unmonitor it - $1 = slot number

killunmonwg()
{

  # Stop the service
  echo -e "${CGreen}\nMessages:                           ${CClear}"
  echo ""
  printf "${CGreen}\r[Stopping WG Client $1]"
  service "stop_wgc $1" >/dev/null 2>&1
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WGC$1 has been stopped and no longer being monitored" >> $logfile
  sleep 10
  printf "\33[2K\r"
  printf "${CGreen}\r[Unmonitoring WG Client $1]"

  # Write the VPN client file back with the correct monitoring configuration
  sed -i "s/^WG$1=.*/WG$1=0/" "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
  sed -i "s/^WGTIMER$1=.*/WGTIMER$1=0/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  sleep 5

  # Restart VPN Director Routing Services
  restartrouting

}

# -------------------------------------------------------------------------------------------------------------------------
# Whitelist Server Slot IP lists in Skynet - $1 = VPN Slot

skynetwhitelist()
{
  if [ "$updateskynet" = "1" ]
  then
    ##-------------------------------------##
    ## Modified by Dan G. [2025-Jul-15]    ##
    ##-------------------------------------##
    if echo "$1" | grep -q "wg"; then
      slotnum=$(echo "$1" | tr -cd '0-9')
      printf "${CGreen}\r[Whitelisting WG Server Slot $slotnum List in the Skynet Firewall]${CClear}\n"
      awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr${slotnum}.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
      firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 - WG Server Slot $slotnum Whitelisted on $date" >/dev/null 2>&1
      rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WG Server Slot $slotnum List has been whitelisted in Skynet" >> $logfile
    else
      printf "${CGreen}\r[Whitelisting VPN Server Slot $1 List in the Skynet Firewall]${CClear}\n"
      firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr$1.txt "VPNMON-R3 - VPN Server Slot $1 Whitelisted on $date" >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Server Slot $1 List has been whitelisted in Skynet" >> $logfile
    fi
    sleep 5
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Reset the  VPN connection timer

resettimer()
{

 # Create initial vr3timers.txt file if it does not exist
  if [ ! -f /jffs/addons/vpnmon-r3.d/vr3timers.txt ]; then

    if [ "$availableslots" = "1 2" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt

    elif [ "$availableslots" = "1 2 3 4 5" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
        echo 'VPNTIMER3=0'
        echo 'VPNTIMER4=0'
        echo 'VPNTIMER5=0'
        echo 'WGTIMER1=0'
        echo 'WGTIMER2=0'
        echo 'WGTIMER3=0'
        echo 'WGTIMER4=0'
        echo 'WGTIMER5=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt

    fi
  fi

  source /jffs/addons/vpnmon-r3.d/vr3timers.txt
  source /jffs/addons/vpnmon-r3.d/vr3clients.txt


  vpnslottmp="VPN${1}"
  eval vpnslottmp="\$${vpnslottmp}"
  wgslottmp="WG${1}"
  eval wgslottmp="\$${wgslottmp}"

  if [ "$2" = "VPN" ] && [ "$vpnslottmp" = "1" ]; then
    sed -i "s/^VPNTIMER$1=.*/VPNTIMER$1=$(date +%s)/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  elif [ "$2" = "WG" ] && [ "$wgslottmp" = "1" ]; then
    sed -i "s/^WGTIMER$1=.*/WGTIMER$1=$(date +%s)/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  fi

  source /jffs/addons/vpnmon-r3.d/vr3timers.txt
  source /jffs/addons/vpnmon-r3.d/vr3clients.txt

}

# -------------------------------------------------------------------------------------------------------------------------
# Reset the managed VPN connections

vreset()
{
  # Grab the VPNMON-R3 config file and read it in
  if [ -f "$config" ]
  then
    source "$config"
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 1
  fi

  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]
  then
    source /jffs/addons/vpnmon-r3.d/vr3clients.txt
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Client Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 1
  fi

  # Create a rudimentary lockfile so that VPNMON-R3 doesn't interfere during the reset
  echo -n > $lockfile

  slot=0
  for slot in $availableslots #loop through the 2/5 vpn slots
  do
      clear
      echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v$version | $(date)                                         ${CClear}\n"
      echo -e "${CGreen}[VPN Connection Reset Commencing]"
      echo ""
      echo -e "${CGreen}[Checking VPN Slot $slot]"
      echo ""
      sleep 2

      #determine if the slot is monitored and reset it
      if [ "$((VPN$slot))" = "1" ]
      then
        if [ "$refreshserverlists" -eq 1 ]
        then
          if [ -f "/jffs/addons/vpnmon-r3.d/vr3svr$slot.txt" ]
          then
            echo -e "${CGreen}[Executing Custom Server List Script for VPN Slot $slot]${CClear}"
            slottmp="automation${slot}"
            eval slottmp="\$${slottmp}"
            if [ -z "$slottmp" ]
            then
              echo ""
              echo -e "${CGreen}[Custom VPN Client Server Query not found for VPN Slot $slot]${CClear}"
            else
              automationunenc="$(echo "$slottmp" | openssl enc -d -base64 -A)"
              echo ""
              echo -e "${CClear}Running: $automationunenc"
              echo ""

              eval "$automationunenc" > "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt"
              if [ -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" ]
              then
                dlcnt=$(cat "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" | wc -l) >/dev/null 2>&1
                if [ -z "$dlcnt" ] || [ "$dlcnt" -lt 1 ]
                then dlcnt=0 ; fi
              else
                dlcnt=0
              fi

              if [ "$dlcnt" -gt 1 ]
              then
                cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3svr$slot.txt" >/dev/null 2>&1
                rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
                echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Client Server List Query Executed for VPN Slot $slot ($dlcnt rows)" >> $logfile
                sleep 3
                echo ""
                skynetwhitelist $slot
                echo ""
              else
                rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
                echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for VPN Slot $slot yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
                sendmessage 1 "VPN Server List Query Yielded 0 Rows" $slot
                sleep 3
                echo ""
              fi
            fi
          else
            echo ""
            echo -e "${CRed}[Custom VPN Client Server List File not found for VPN Slot $slot]${CClear}"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List File not found for VPN Slot $slot" >> $logfile
            sleep 3
          fi
        fi

        restartvpn $slot
        dvpn_on_tunnel_restart "ovpn" "$slot";
        sendmessage 0 "VPN Connection Scheduled Reset" $slot

      fi
  done

  slot=0
  for slot in $availableslots #loop through the 5 wg slots
  do
      clear
      echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v$version | $(date)                                         ${CClear}\n"
      echo -e "${CGreen}[WG Connection Reset Commencing]"
      echo ""
      echo -e "${CGreen}[Checking WG Slot $slot]"
      echo ""
      sleep 2

      #determine if the slot is monitored and reset it
      if [ "$((WG$slot))" = "1" ]
      then
        if [ "$refreshserverlists" -eq 1 ]
        then
          if [ -f "/jffs/addons/vpnmon-r3.d/vr3wgsvr$slot.txt" ]
          then
            echo -e "${CGreen}[Executing Custom WG Server List Script for WG Slot $slot]${CClear}"
            slottmp="wgautomation${slot}"
            eval slottmp="\$${slottmp}"
            if [ -z "$slottmp" ]
            then
              echo ""
              echo -e "${CGreen}[Custom WG Client Server Query not found for WG Slot $slot]${CClear}"
            else
              wgautomationunenc="$(echo "$slottmp" | openssl enc -d -base64 -A)"
              echo ""
              echo -e "${CClear}Running: $wgautomationunenc"
              echo ""

              eval "$wgautomationunenc" > "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt"
              if [ -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" ]
              then
                dlcnt=$(cat "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" | wc -l) >/dev/null 2>&1
                if [ -z "$dlcnt" ] || [ "$dlcnt" -lt 1 ]
                then dlcnt=0 ; fi
              else
                dlcnt=0
              fi

              if [ "$dlcnt" -gt 1 ]
              then
                cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr$slot.txt" >/dev/null 2>&1
                rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
                echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom WG Client Server List Query Executed for WG Slot $slot ($dlcnt rows)" >> $logfile
                sleep 3
                echo ""
                skynetwhitelist wg$slot
                echo ""
              else
                rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
                echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List Query for WG Slot $slot yielded 0 rows -- Query may be invalid or WG API service may be down" >> $logfile
                sendmessage 1 "WG Server List Query Yielded 0 Rows" $slot
                sleep 3
                echo ""
              fi
            fi
          else
            echo ""
            echo -e "${CRed}[Custom WG Client Server List File not found for WG Slot $slot]${CClear}"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom WG Client Server List File not found for WG Slot $slot" >> $logfile
            sleep 3
          fi
        fi
        restartwg $slot
        dvpn_on_tunnel_restart "wg" "$slot"
        sendmessage 0 "WG Connection Scheduled Reset" $slot

      fi
  done

  restartrouting
  resetspdmerlin

  echo -e "${CGreen}[Reset Complete]${CClear}"

  # Clean up lockfile
  rm -f $lockfile >/dev/null 2>&1

  echo -e "\n${CClear}"
  exit 0
}

# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Oct-18] ##
##----------------------------------------##
# Find the VPN IP
getvpnip()
{
  ubsync=""
  TUN="tun1$1"

  icanhazvpnip="$($timeoutcmd$timeoutsec nvram get vpn_client$1_rip)"
  if [ -z "$icanhazvpnip" ] || [ "$icanhazvpnip" = "unknown" ]
  then
     # Grab the public IP of the VPN Connection #
     icanhazvpnip="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --interface "$TUN" --request GET --url https://ipv4.icanhazip.com"
     icanhazvpnip="$(eval $icanhazvpnip)"
     if [ -z "$icanhazvpnip" ] || echo "$icanhazvpnip" | grep -qoE 'Internet|traffic|Error|error' ; then icanhazvpnip="0.0.0.0" ; fi
  fi

  if [ -z "$icanhazvpnip" ]
  then
      vpnip="000.000.000.000"
      return
  else
      vpnip="$(printf '%15s' "$icanhazvpnip")"
  fi

  if [ "$unboundclient" -ne 0 ] && [ "$unboundclient" -eq "$1" ]
  then
    if [ "$ResolverTimer" -eq 1 ]; then
      ResolverTimer=0
      if [ "$unboundshowip" -eq 0 ]; then
        ubsync="${CYellow}-?[UB]${CClear}"
      else
        ubsync="${CYellow}-?[UB:Resolving]${CClear}"
      fi
    else
      # Huge thanks to @SomewhereOverTheRainbow for his expertise in troublshooting and coming up with this DNS Resolver methodology!
      DNSResolver="$({ unbound-control flush whoami.akamai.net >/dev/null 2>&1; } && dig whoami.akamai.net +short @"$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{split($4, ip_addr, ":");if(substr($4,11) !~ /.*953.*/)print ip_addr[1];if(substr($4,11) !~ /.*953.*/)exit}')" -p "$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{if(substr($4,11) !~ /.*953.*/)print substr($4,11);if(substr($4,11) !~ /.*953.*/)exit}')" 2>/dev/null)"

      if [ -z "$DNSResolver" ]
      then
        if [ "$unboundshowip" -eq 0 ]; then
          ubsync="${CRed}-X[UB]${CClear}"
        else
          ubsync="${CRed}-X[UB:$DNSResolver]${CClear}"
        fi
      # rudimentary check to make sure value coming back is in the format of an IP address... Don't care if it's more than 255.
      elif expr "$DNSResolver" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null
      then
        # If the DNS resolver and public VPN IP address don't match in our Unbound scenario, reset!
        if [ "$DNSResolver" != "$icanhazvpnip" ]
        then
          if [ "$unboundshowip" -eq 0 ]; then
            ubsync="${CRed}-X[UB]${CClear}"
          else
            ubsync="${CRed}-X[UB:$DNSResolver]${CClear}"
          fi
          ResolverTimer=1
          unboundreset=$1
        else
          if [ "$unboundshowip" -eq 0 ]; then
            ubsync="${CGreen}->[UB]${CClear}"
          else
            ubsync="${CGreen}->[UB:$DNSResolver]${CClear}"
          fi
        fi
      else
        if [ "$unboundshowip" -eq 0 ]; then
          ubsync="${CYellow}-?[UB]${CClear}"
        else
          ubsync="${CYellow}-?[UB:$DNSResolver]${CClear}"
        fi
      fi
    fi
  else
    ubsync=""
  fi

  # Insert bogus IP if screenshotmode is on #
  if [ "$screenshotmode" = "1" ]; then
     vpnip="$(printf '%15s' "12.34.56.78")"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
##-----------------------------------------------------------------------------------------##
## Modified by ViktorJp [2025-Jul-06], origial getvpnip modded by Martinski. [2024-Oct-18] ##
##-----------------------------------------------------------------------------------------##
# Find the WG IP
getwgip()
{
  ubsync=""
  TUN="wgc$1"

  # Added ping workaround for site2site scenarios based on suggestion from @ZebMcKayhan
  TUN_IP=$($timeoutcmd$timeoutsec nvram get "$TUN"_addr | cut -d '/' -f1)
  ip rule add from $TUN_IP lookup $TUN prio 10 >/dev/null 2>&1

  icanhazwgip="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --interface "$TUN" --request GET --url https://ipv4.icanhazip.com"
  icanhazwgip="$(eval $icanhazwgip)"
  if [ -z "$icanhazwgip" ] || echo "$icanhazwgip" | grep -qoE 'Internet|traffic|Error|error' ; then icanhazwgip="0.0.0.0" ; fi

  if [ -z "$icanhazwgip" ]
  then
      wgip="000.000.000.000"
      return
  else
      wgip="$(printf '%15s' "$icanhazwgip")"
  fi

  if [ "$unboundwgclient" -ne 0 ] && [ "$unboundwgclient" -eq "$1" ]
  then
    if [ "$ResolverTimer" -eq 1 ]; then
      ResolverTimer=0
      if [ "$unboundshowip" -eq 0 ]; then
        ubsync="${CYellow}-?[UB]${CClear}"
      else
        ubsync="${CYellow}-?[UB:Resolving]${CClear}"
      fi
    else
      # Huge thanks to @SomewhereOverTheRainbow for his expertise in troublshooting and coming up with this DNS Resolver methodology!
      DNSResolver="$({ unbound-control flush whoami.akamai.net >/dev/null 2>&1; } && dig whoami.akamai.net +short @"$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{split($4, ip_addr, ":");if(substr($4,11) !~ /.*953.*/)print ip_addr[1];if(substr($4,11) !~ /.*953.*/)exit}')" -p "$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{if(substr($4,11) !~ /.*953.*/)print substr($4,11);if(substr($4,11) !~ /.*953.*/)exit}')" 2>/dev/null)"

      if [ -z "$DNSResolver" ]
      then
        if [ "$unboundshowip" -eq 0 ]; then
          ubsync="${CRed}-X[UB]${CClear}"
        else
          ubsync="${CRed}-X[UB:$DNSResolver]${CClear}"
        fi
      # rudimentary check to make sure value coming back is in the format of an IP address... Don't care if it's more than 255.
      elif expr "$DNSResolver" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null
      then
        # If the DNS resolver and public VPN IP address don't match in our Unbound scenario, reset!
        if [ "$DNSResolver" != "$icanhazwgip" ]
        then
          if [ "$unboundshowip" -eq 0 ]; then
            ubsync="${CRed}-X[UB]${CClear}"
          else
            ubsync="${CRed}-X[UB:$DNSResolver]${CClear}"
          fi
          ResolverTimer=1
          unboundreset=$1
        else
          if [ "$unboundshowip" -eq 0 ]; then
            ubsync="${CGreen}->[UB]${CClear}"
          else
            ubsync="${CGreen}->[UB:$DNSResolver]${CClear}"
          fi
        fi
      else
        if [ "$unboundshowip" -eq 0 ]; then
          ubsync="${CYellow}-?[UB]${CClear}"
        else
          ubsync="${CYellow}-?[UB:$DNSResolver]${CClear}"
        fi
      fi
    fi
  else
    ubsync=""
  fi

  # Added based on suggestion from @ZebMcKayhan
  ip rule del prio 10 >/dev/null 2>&1

  # Insert bogus IP if screenshotmode is on #
  if [ "$screenshotmode" = "1" ]; then
     wgip="$(printf '%15s' "12.34.56.78")"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Oct-18] ##
##----------------------------------------##
# Find and remember the VPN city so it doesn't have to make successive API lookups
getvpncity()
{
  if [ "$icanhazvpnip" = "0.0.0.0" ]; then
     vpncity="Undetermined"
     return
  fi

  if [ "$1" = "1" ]
  then
    lastvpnip1="$icanhazvpnip"
    if [ "$lastvpnip1" != "$oldvpnip1" ]
    then
      vpncity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"
      if [ -z "$vpncity" ] || echo "$vpncity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then vpncity="Undetermined" ; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity1="$vpncity"
    fi
    vpncity="$vpncity1"
    oldvpnip1="$lastvpnip1"
  elif [ "$1" = "2" ]
  then
    lastvpnip2="$icanhazvpnip"
    if [ "$lastvpnip2" != "$oldvpnip2" ]
    then
      vpncity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"
      if [ -z "$vpncity" ] || echo "$vpncity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then vpncity="Undetermined" ; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity2="$vpncity"
    fi
    vpncity="$vpncity2"
    oldvpnip2="$lastvpnip2"
  elif [ "$1" = "3" ]
  then
    lastvpnip3="$icanhazvpnip"
    if [ "$lastvpnip3" != "$oldvpnip3" ]
    then
      vpncity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"
      if [ -z "$vpncity" ] || echo "$vpncity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then vpncity="Undetermined" ; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity3="$vpncity"
    fi
    vpncity="$vpncity3"
    oldvpnip3="$lastvpnip3"
  elif [ "$1" = "4" ]
  then
    lastvpnip4="$icanhazvpnip"
    if [ "$lastvpnip4" != "$oldvpnip4" ]
    then
      vpncity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"
      if [ -z "$vpncity" ] || echo "$vpncity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then vpncity="Undetermined" ; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity4="$vpncity"
    fi
    vpncity="$vpncity4"
    oldvpnip4="$lastvpnip4"
  elif [ "$1" = "5" ]
  then
    lastvpnip5="$icanhazvpnip"
    if [ "$lastvpnip5" != "$oldvpnip5" ]
    then
      vpncity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"
      if [ -z "$vpncity" ] || echo "$vpncity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then vpncity="Undetermined" ; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity5="$vpncity"
    fi
    vpncity="$vpncity5"
    oldvpnip5="$lastvpnip5"
  fi

  # Insert bogus City if screenshotmode is on
  if [ "$screenshotmode" = "1" ]; then
     vpncity="Gotham City"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
##------------------------------------------------------------------------------------------------##
## Modified by ViktorJp [2025-Jul-06], Original getvpncity() modded bt Martinski W. [2024-Oct-18] ##
##------------------------------------------------------------------------------------------------##
# Find and remember the WG city so it doesn't have to make successive API lookups
getwgcity()
{
  if [ "$icanhazwgip" = "0.0.0.0" ]; then
     wgcity="Undetermined"
     return
  fi

  # Added ping workaround for site2site scenarios based on suggestion from @ZebMcKayhan
  TUN_IP=$($timeoutcmd$timeoutsec nvram get "$TUN"_addr | cut -d '/' -f1)
  ip rule add from $TUN_IP lookup $TUN prio 10 >/dev/null 2>&1

  if [ "$1" = "1" ]
  then
    lastwgip1="$icanhazwgip"
    if [ "$lastwgip1" != "$oldwgip1" ]
    then
      wgcity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
      wgcity="$(eval $wgcity)"
      if [ -z "$wgcity" ] || echo "$wgcity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then wgcity="Undetermined" ; fi
      wgcitychange="${CGreen}- NEW ${CClear}"
      wgcity1="$wgcity"
    fi
    wgcity="$wgcity1"
    oldwgip1="$lastwgip1"
  elif [ "$1" = "2" ]
  then
    lastwgip2="$icanhazwgip"
    if [ "$lastwgip2" != "$oldwgip2" ]
    then
      wgcity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
      wgcity="$(eval $wgcity)"
      if [ -z "$wgcity" ] || echo "$wgcity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then wgcity="Undetermined" ; fi
      wgcitychange="${CGreen}- NEW ${CClear}"
      wgcity2="$wgcity"
    fi
    wgcity="$wgcity2"
    oldwgip2="$lastwgip2"
  elif [ "$1" = "3" ]
  then
    lastwgip3="$icanhazwgip"
    if [ "$lastwgip3" != "$oldwgip3" ]
    then
      wgcity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
      wgcity="$(eval $wgcity)"
      if [ -z "$wgcity" ] || echo "$wgcity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then wgcity="Undetermined" ; fi
      wgcitychange="${CGreen}- NEW ${CClear}"
      wgcity3="$wgcity"
    fi
    wgcity="$wgcity3"
    oldwgip3="$lastwgip3"
  elif [ "$1" = "4" ]
  then
    lastwgip4="$icanhazwgip"
    if [ "$lastwgip4" != "$oldwgip4" ]
    then
      wgcity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
      wgcity="$(eval $wgcity)"
      if [ -z "$wgcity" ] || echo "$wgcity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then wgcity="Undetermined" ; fi
      wgcitychange="${CGreen}- NEW ${CClear}"
      wgcity4="$wgcity"
    fi
    wgcity="$wgcity4"
    oldwgip4="$lastwgip4"
  elif [ "$1" = "5" ]
  then
    lastwgip5="$icanhazwgip"
    if [ "$lastwgip5" != "$oldwgip5" ]
    then
      wgcity="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
      wgcity="$(eval $wgcity)"
      if [ -z "$wgcity" ] || echo "$wgcity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then wgcity="Undetermined" ; fi
      wgcitychange="${CGreen}- NEW ${CClear}"
      wgcity5="$wgcity"
    fi
    wgcity="$wgcity5"
    oldwgip5="$lastwgip5"
  fi

  # Added based on suggestion from @ZebMcKayhan
  ip rule del prio 10 >/dev/null 2>&1

  # Insert bogus City if screenshotmode is on
  if [ "$screenshotmode" = "1" ]; then
     wgcity="Gotham City"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Check health of the vpn connection using PING and CURL

checkvpn()
{
  CNT=0
  #TRIES=3
  TUN="tun1$1"

  while [ "$CNT" -lt "$recover" ]; do # Loop through number of tries
    ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings to Primary PING Host
    RC=$?
    ping -I $TUN -q -c 1 -W 2 $PINGHOST2 > /dev/null 2>&1 # Then try pings to Secondary PING Host
    SC=$?
    if [ "$RC" -eq 0 ] || [ "$SC" -eq 0 ]; then # Grab the public IP of the VPN Connection #
      COMBOPING=0
      ICANHAZIP="$(curl --silent --fail --retry 3 --retry-delay 1 --retry-all-errors --max-time 10 --interface "$TUN" --request GET --url https://ipv4.icanhazip.com)"
      IC=$?
    else
      COMBOPING=1
      IC=2
    fi
    if [ "$COMBOPING" -eq 0 ] && [ "$IC" -eq 0 ]; then  # If both ping/curl come back successful, then proceed
      vpnping=$(ping -I $TUN -c 1 -W 2 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
      VP=$?
      if [ "$VP" -eq 0 ]; then
        vpnhealth="${CGreen}[ OK ]${CClear}"
        vpnindicator="${InvGreen} ${CClear}"
        if [ "$problemvpnslot" -eq "$1" ]; then
          vrcnt=0
          problemvpnslot=0
        fi
      else
        vpnping=0
        vpnhealth="${CYellow}[UNKN]${CClear}"
        vpnindicator="${InvYellow} ${CClear}"
      fi
      printf "\33[2K\r"
      break
    else
      CNT="$((CNT+1))"
      printf "\33[2K\r"
      printf "\r${InvDkGray} ${CWhite} VPN$1${CClear} [Attempt $CNT]"
      sleep 1 # Giving the VPN a chance to recover a certain number of times

      if [ "$CNT" -eq "$recover" ];then # But if it fails, report back that we have an issue requiring a VPN reset
        printf "\33[2K\r"
        vpnping=0
        vpnhealth="${CRed}[FAIL]${CClear}"
        vpnindicator="${InvRed} ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$1 failed to respond" >> $logfile

        vrcnt="$((vrcnt+1))"
        problemvpnslot="$1"
        if [ "$vrcnt" -ge 10 ]; then
          monitored="${CRed}[!]${CClear}"
        else
          monitored="${CRed}[$vrcnt]${CClear}"
        fi
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$1 attempt $vrcnt of $recover to allow connection to recover" >> $logfile
        if [ "$vrcnt" -eq "$recover" ]; then
          if [ "$((VPN$1))" = "1" ]; then
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$1 failed to respond after $recover attempt(s)" >> $logfile
            resetvpn=$1
          fi
        fi
      fi
    fi
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# Check health of the WG connection using PING and CURL

checkwg()
{
  CNT=0
  #TRIES=3
  TUN="wgc$1"

  # Added ping workaround for site2site scenarios based on suggestion from @ZebMcKayhan
  TUN_IP=$($timeoutcmd$timeoutsec nvram get "$TUN"_addr | cut -d '/' -f1)
  ip rule add from $TUN_IP lookup $TUN prio 10 >/dev/null 2>&1

  while [ "$CNT" -lt "$recover" ]; do # Loop through number of tries
    ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings to Primary PING Host
    RC=$?
    ping -I $TUN -q -c 1 -W 2 $PINGHOST2 > /dev/null 2>&1 # Then try pings to Secondary PING Host
    SC=$?
    if [ "$RC" -eq 0 ] || [ "$SC" -eq 0 ]; then # Grab the public IP of the VPN Connection #
      COMBOPING=0
      ICANHAZIP="$(curl --silent --fail --retry 3 --retry-delay 1 --retry-all-errors --max-time 10 --interface "$TUN" --request GET --url https://ipv4.icanhazip.com)"
      IC=$?
    else
      COMBOPING=1
      IC=2
    fi
    if [ "$COMBOPING" -eq 0 ] && [ "$IC" -eq 0 ]; then  # If both ping/curl come back successful, then proceed
      wgping=$(ping -I $TUN -c 1 -W 2 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
      VP=$?
      if [ "$VP" -eq 0 ]; then
        wghealth="${CGreen}[ OK ]${CClear}"
        wgindicator="${InvGreen} ${CClear}"
        if [ "$problemwgslot" -eq "$1" ]; then
          wrcnt=0
          problemwgslot=0
        fi
      else
        wgping=0
        wghealth="${CYellow}[UNKN]${CClear}"
        wgindicator="${InvYellow} ${CClear}"
      fi
      printf "\33[2K\r"
      break
    else
      CNT="$((CNT+1))"
      printf "\33[2K\r"
      printf "\r${InvDkGray} ${CWhite} WGC$1${CClear} [Attempt $CNT]"
      sleep 1 # Giving the VPN a chance to recover a certain number of times

      if [ "$CNT" -eq "$recover" ]; then # But if it fails, report back that we have an issue requiring a VPN reset
        printf "\33[2K\r"
        wgping=0
        wghealth="${CRed}[FAIL]${CClear}"
        wgindicator="${InvRed} ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$1 failed to respond" >> $logfile

        wrcnt="$((wrcnt+1))"
        problemwgslot="$1"
        if [ "$wrcnt" -ge 10 ]; then
          wgmonitored="${CRed}[!]${CClear}"
        else
          wgmonitored="${CRed}[$wrcnt]${CClear}"
        fi
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$1 attempt $wrcnt of $recover to allow connection to recover" >> $logfile
        if [ "$wrcnt" -eq "$recover" ]; then
          if [ "$((WG$1))" = "1" ]; then
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$1 failed to respond after $recover attempt(s)" >> $logfile
            resetwg=$1
          fi
        fi
      fi
    fi
  done

  # Added based on suggestion from @ZebMcKayhan
  ip rule del prio 10 >/dev/null 2>&1

}

# -------------------------------------------------------------------------------------------------------------------------

# Checkwan is a function that checks the viability of the current WAN connection and will loop until the WAN connection is restored.
checkwan()
{
  # Using Google's DNS server as default to test for WAN connectivity over verified SSL Handshake
  wandownbreakertrip=0
  testssl="$PINGHOST"

  printf "\33[2K\r"
  printf "\r${InvYellow} ${CClear} [Checking WAN Connectivity]..."

  #Run main checkwan loop
  while true
  do
    # Check the actual WAN State from NVRAM before running connectivity test, or insert itself into loop after failing an SSL handshake test
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ] || [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
    then
       # Test the active WAN connection using 443 and verifying a handshake... if this fails, then the WAN connection is most likely down... or Google is down ;)
        sleep 1
        if ($echo | $timeoutcmd$timeoutlng openssl s_client -connect "${testssl}:443" 2>/dev/null | grep -q "SSL handshake has read")
        then
            printf "\r${InvGreen} ${CClear} [Checking WAN Connectivity]...ACTIVE"
            sleep 1
            WCNT=0
            printf "\33[2K\r"
            return
        else
            wandownbreakertrip=1
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: WAN Connectivity Issue Detected - Unable to establish SSL connection with $testssl" >> $logfile
        fi
    else
        wandownbreakertrip=1
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: WAN Connectivity Issue Detected - Unable to establish SSL connection with $testssl" >> $logfile
    fi

    if [ "$wandownbreakertrip" = "1" ]
    then

      WCNT="$((WCNT+1))"
      printf "\33[2K\r"
      printf "\r${InvRed} ${CClear} WAN Connectivity Failure Detected [Attempt $WCNT | $recoverytimer sec/attempt]"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WAN attempt $WCNT of $recover to allow connection to recover" >> $logfile
      sleep $recoverytimer # Giving the WAN a chance to recover a certain number of times - default: recoverytimer=10

      if [ "$WCNT" -eq "$recover" ] # But if it fails, report back that we have an issue requiring a WAN DOWN event
      then
        printf "\33[2K\r"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WAN failed to respond after $recover attempts" >> $logfile

        # The WAN is most likely down, and keep looping through until NVRAM reports that it's back up
        while [ "$wandownbreakertrip" = "1" ]
        do
          if [ "$availableslots" = "1 2" ]
          then
            state1="$(_VPN_GetClientState_ 1)"
            state2="$(_VPN_GetClientState_ 2)"
            printf "\r${InvGreen} ${CClear} [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2                                   "
            sleep 3
          elif [ "$availableslots" = "1 2 3 4 5" ]
          then
            state1="$(_VPN_GetClientState_ 1)"
            state2="$(_VPN_GetClientState_ 2)"
            state3="$(_VPN_GetClientState_ 3)"
            state4="$(_VPN_GetClientState_ 4)"
            state5="$(_VPN_GetClientState_ 5)"
            printf "\r${InvGreen} ${CClear} [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2 3:$state3 4:$state4 5:$state5     "
            sleep 3
          fi

          # Preemptively kill all the VPN Clients incase they're trying to reconnect on their own
          for slot in $availableslots
          do
              if [ $((state$slot)) -ne 0 ]; then
                printf "\r${InvGreen} ${CClear} [Retrying Kill Command on VPN$slot Client Connection]...              "
                service stop_vpnclient$slot >/dev/null 2>&1
                sleep 3
              fi
          done

          # Check the wireguard side and bring those down as well
          if [ "$availableslots" = "1 2 3 4 5" ]
          then
            wgstate1="$(_WG_GetClientState_ 1)"
            wgstate2="$(_WG_GetClientState_ 2)"
            wgstate3="$(_WG_GetClientState_ 3)"
            wgstate4="$(_WG_GetClientState_ 4)"
            wgstate5="$(_WG_GetClientState_ 5)"
            printf "\r${InvGreen} ${CClear} [Confirming WG Clients Disconnected]... 1:$wgstate1 2:$wgstate2 3:$wgstate3 4:$wgstate4 5:$wgstate5     "
            sleep 3
          fi

          # Preemptively kill all the WG Clients incase they're trying to reconnect on their own
          for slot in $availableslots
          do
              if [ $((wgstate$slot)) -ne 0 ]; then
                printf "\r${InvGreen} ${CClear} [Retrying Kill Command on WGC$slot Client Connection]...              "
                service "stop_wgc $slot" >/dev/null 2>&1
                sleep 3
              fi
          done

          # Continue to test for WAN connectivity while in this loop. If it comes back up, break out of the loop and reset VPN
          if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -ne 2 ] && [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -ne 2 ]
          then
              # Continue to loop and retest the WAN every 15 seconds
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: WAN DOWN" >> $logfile
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Router is Currently Experiencing a WAN Down Situation                                 ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Router is unable to provide a stable WAN connection. Please reboot your modem,${CClear}"
              echo -e "${InvGreen} ${CClear} check with your ISP, or perform general internet connectivity troubleshooting${CClear}"
              echo -e "${InvGreen} ${CClear} in order to re-establish a stable VPN connection.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} [Retrying to resume normal operations roughly every $wandowntimer seconds]${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              spinner $wandowntimer # Time between attempts to determine if WAN becomes available again - Default: wandowntimer=60
              wandownbreakertrip=1
          else
              wandownbreakertrip=2
              break
          fi
        done
      else
        wandownbreakertrip=0
      fi
    fi

      # If the WAN was down, and now it has just reset, then run a VPN Reset, and try to establish a new VPN connection
      if [ "$wandownbreakertrip" = "2" ]
      then
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WAN Link Detected -- Trying to Reconnect/Reset VPN/WG" >> $logfile
          wandownbreakertrip=0
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 is currently recovering from a WAN Down Situation                           ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Router has detected a WAN Link/Modem and waiting $reconnecttimer seconds for general network${CClear}"
          echo -e "${InvGreen} ${CClear} connectivity to stabilize before re-establishing VPN/WG connectivity.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} [Retrying to resume normal operations in roughly $reconnecttimer seconds...Please stand by!]${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          spinner $reconnecttimer  # Time allotted to give router chance to recover before reconnecting tunnels - Default: reconnecttimer=300
          #sendmessage 1 "Recovering from WAN Down" - this doesn't work when the internet is down
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi
  done
}

# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Oct-18] ##
##----------------------------------------##
# wancheck is a function that checks each wan connection to see if its active, and performs a ping and a city lookup...
wancheck()
{
  WANIF="$1"
  WANIFNAME="$(get_wan_setting ifname)"
  DUALWANMODE="$($timeoutcmd$timeoutsec nvram get wans_mode)"

  # Uptime calc #
  uptimeStr="$(awk '{printf("%dd %02dh:%02dm\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)"

  # If WAN 0 or 1 is connected, then proceed, else display that it's inactive
  if [ "$WANIF" = "0" ]
  then
     if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ]
     then
        # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
        WAN0IFNAME="$(get_wan_setting0 ifname)"

        # Ping through the WAN interface #
        if [ "$WANIFNAME" = "$WAN0IFNAME" ] || [ "$DUALWANMODE" = "lb" ]
        then
            WAN0PING="$(ping -I "$WAN0IFNAME" -c 1 "$PINGHOST" 2>/dev/null | awk -F'[/=]' 'END{print $5}')"
            ## No need to do left-padding with zeros for alignment ##
            [ -n "${WAN0PING:+xSETx}" ] && WAN0PING="$(printf "[%8.3f]" "$WAN0PING")"
        else
            WAN0PING="[FAILOVER]"
        fi

        # On the rare occasion where it's unable to get the Ping time, show ERROR #
        if [ -z "$WAN0PING" ] ; then WAN0PING="${CRed}[PING ERR]${CClear}" ; fi

        # Get the public IP of the WAN, determine the city from it, and display it on screen #
        if [ -z "${WAN0IP:+xSETx}" ]
        then
           WAN0IP="$(curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --interface "$WAN0IFNAME" --request GET --url https://ipv4.icanhazip.com)"
           WAN0CITY="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$WAN0IP | jq --raw-output .city"
           WAN0CITY="$(eval $WAN0CITY)"
           if [ -z "$WAN0CITY" ] || echo "$WAN0CITY" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then WAN0CITY="$WAN0IP" ; fi
           WAN0IP="$(printf '%15s' "$WAN0IP")"
        fi

        # Insert bogus IP and City if screenshotmode is on
        if [ "$screenshotmode" = "1" ]
        then
           WAN0CITY="Metropolis"
           WAN0IP="$(printf '%15s' "11.22.33.44")"
        fi

        WAN0BWRX="$(printf '%4s' "$diffwan0rxbytes")"
        if [ -z "$diffwan0rxbytes" ] || [ "$diffwan0rxbytes" = "" ] || [ "$diffwan0rxbytes" -lt 0 ]
        then
          WAN0RX1="${CRed}[UNKN]${CClear}"
        elif [ "$diffwan0rxbytes" -ge 0 ] && [ "$diffwan0rxbytes" -le "$lowutilspd" ]
        then
          WAN0RX1="${CGreen}[$WAN0BWRX]${CClear}"
        elif [ "$diffwan0rxbytes" -gt "$lowutilspd" ] && [ "$diffwan0rxbytes" -le "$medutilspd" ]
        then
          WAN0RX1="${CYellow}[$WAN0BWRX]${CClear}"
        elif [ "$diffwan0rxbytes" -gt "$medutilspd" ]
        then
          WAN0RX1="${CRed}[$WAN0BWRX]${CClear}"
        fi

        WAN0BWTX="$(printf '%4s' "$diffwan0txbytes")"
        if [ -z "$diffwan0txbytes" ] || [ "$diffwan0txbytes" = "" ] || [ "$diffwan0txbytes" -lt 0 ]
        then
          WAN0TX1="${CRed}[UNKN]${CClear}"
        elif [ "$diffwan0txbytes" -ge 0 ] && [ "$diffwan0txbytes" -le "$lowutilspdup" ]
        then
          WAN0TX1="${CGreen}[$WAN0BWTX]${CClear}"
        elif [ "$diffwan0txbytes" -gt "$lowutilspdup" ] && [ "$diffwan0txbytes" -le "$medutilspdup" ]
        then
          WAN0TX1="${CYellow}[$WAN0BWTX]${CClear}"
        elif [ "$diffwan0txbytes" -gt "$medutilspdup" ]
        then
          WAN0TX1="${CRed}[$WAN0BWTX]${CClear}"
        fi

        WAN0TPRX="$(printf '%4s' "$thruwan0rxbytes")"
        if [ -z "$thruwan0rxbytes" ] || [ "$thruwan0rxbytes" = "" ] || [ "$thruwan0rxbytes" -lt 0 ]
        then
          WAN0RX2="${CRed}[UNKN]${CClear}"
        elif [ "$thruwan0rxbytes" -ge 0 ] && [ "$thruwan0rxbytes" -le "$lowutilspd" ]
        then
          WAN0RX2="${CGreen}[$WAN0TPRX]${CClear}"
        elif [ "$thruwan0rxbytes" -gt "$lowutilspd" ] && [ "$thruwan0rxbytes" -le "$medutilspd" ]
        then
          WAN0RX2="${CYellow}[$WAN0TPRX]${CClear}"
        elif [ "$thruwan0rxbytes" -gt "$medutilspd" ]
        then
          WAN0RX2="${CRed}[$WAN0TPRX]${CClear}"
        fi

        WAN0TPTX="$(printf '%4s' "$thruwan0txbytes")"
        if [ -z "$thruwan0txbytes" ] || [ "$thruwan0txbytes" = "" ] || [ "$thruwan0txbytes" -lt 0 ]
        then
          WAN0TX2="${CRed}[UNKN]${CClear}"
        elif [ "$thruwan0txbytes" -ge 0 ] && [ "$thruwan0txbytes" -le "$lowutilspdup" ]
        then
          WAN0TX2="${CGreen}[$WAN0TPTX]${CClear}"
        elif [ "$thruwan0txbytes" -gt "$lowutilspdup" ] && [ "$thruwan0txbytes" -le "$medutilspdup" ]
        then
          WAN0TX2="${CYellow}[$WAN0TPTX]${CClear}"
        elif [ "$thruwan0txbytes" -gt "$medutilspdup" ]
        then
          WAN0TX2="${CRed}[$WAN0TPTX]${CClear}"
        fi

        if [ "$WCNT" -ge 1 ]; then
          wan0status="${CRed}[$WCNT]${CClear}"
          wan0health="${CRed}[FAIL]${CClear}"
        else
          wan0status="${CGreen}[X]${CClear}"
          wan0health="${CGreen}[ OK ]${CClear}"
        fi

        if [ "$WAN0PING" = "[FAILOVER]" ]
        then
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN0${CClear} | $wan0status | "
           printf "%-6s" "${WAN0IFNAME:0:6}"
           if [ "$bwdisp" = "1" ]; then
             echo -e " | $wan0health | Failover     | $WAN0IP | $WAN0PING | $WAN0RX1 | $WAN0TX1 | $WAN0CITY: $uptimeStr"
           else
             echo -e " | $wan0health | Failover     | $WAN0IP | $WAN0PING | $WAN0RX2 | $WAN0TX2 | $WAN0CITY: $uptimeStr"
           fi
        else
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN0${CClear} | $wan0status | "
           printf "%-6s" "$WAN0IFNAME"
           if [ "$bwdisp" = "1" ]; then
             echo -e " | $wan0health | ${CGreen}Active${CClear}       | $WAN0IP | $WAN0PING | $WAN0RX1 | $WAN0TX1 | $WAN0CITY: $uptimeStr"
           else
             echo -e " | $wan0health | ${CGreen}Active${CClear}       | $WAN0IP | $WAN0PING | $WAN0RX2 | $WAN0TX2 | $WAN0CITY: $uptimeStr"
           fi
        fi
     else
        echo -e "${InvDkGray}${CWhite}  WAN0${CClear} | ${CGreen}[X]${CClear} | ${CDkGray}[n/a]${CClear}  | ${CDkGray}[n/a ]${CClear} | Inactive     |           ${CDkGray}[n/a]${CClear} |      ${CDkGray}[n/a]${CClear} | ${CDkGray}[n/a ]${CClear} | ${CDkGray}[n/a ]${CClear} | ${CDkGray}[n/a]${CClear}"
     fi
  fi

  if [ "$WANIF" = "1" ]
  then
     if [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
     then
        # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
        WAN1IFNAME="$(get_wan_setting1 ifname)"

        # Ping through the WAN interface #
        if [ "$WANIFNAME" = "$WAN1IFNAME" ] || [ "$DUALWANMODE" = "lb" ]
        then
            WAN1PING="$(ping -I "$WAN1IFNAME" -c 1 "$PINGHOST" 2>/dev/null | awk -F'[/=]' 'END{print $5}')"
            ## No need to do left-padding with zeros for alignment ##
            [ -n "${WAN1PING:+xSETx}" ] && WAN1PING="$(printf "[%8.3f]" "$WAN1PING")"
        else
            WAN1PING="[FAILOVER]"
        fi

        # On the rare occasion where it's unable to get the Ping time, show ERROR #
        if [ -z "$WAN1PING" ] ; then WAN1PING="${CRed}[PING ERR]${CClear}" ; fi

        # Get the public IP of the WAN, determine the city from it, and display it on screen #
        if [ -z "${WAN1IP:+xSETx}" ]
        then
           WAN1IP="$(curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --interface "$WAN1IFNAME" --request GET --url https://ipv4.icanhazip.com)"
           WAN1CITY="curl --silent --fail --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$WAN1IP | jq --raw-output .city"
           WAN1CITY="$(eval $WAN1CITY)"
           if [ -z "$WAN1CITY" ] || echo "$WAN1CITY" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then WAN1CITY="$WAN1IP" ; fi
           WAN1IP="$(printf '%15s' "$WAN1IP")"
        fi

        WAN1BWRX="$(printf '%4s' "$diffwan1rxbytes")"
        if [ -z "$diffwan1rxbytes" ] || [ "$diffwan1rxbytes" = "" ] || [ "$diffwan1rxbytes" -lt 0 ]
        then
          WAN1RX1="${CRed}[UNKN]${CClear}"
        elif [ "$diffwan1rxbytes" -ge 0 ] && [ "$diffwan1rxbytes" -le "$lowutilspd" ]
        then
          WAN1RX1="${CGreen}[$WAN1BWRX]${CClear}"
        elif [ "$diffwan1rxbytes" -gt "$lowutilspd" ] && [ "$diffwan1rxbytes" -le "$medutilspd" ]
        then
          WAN1RX1="${CYellow}[$WAN1BWRX]${CClear}"
        elif [ "$diffwan1rxbytes" -gt "$medutilspd" ]
        then
          WAN1RX1="${CRed}[$WAN1BWRX]${CClear}"
        fi

        WAN1BWTX="$(printf '%4s' "$diffwan1txbytes")"
        if [ -z "$diffwan1txbytes" ] || [ "$diffwan1txbytes" = "" ] || [ "$diffwan1txbytes" -lt 0 ]
        then
          WAN1TX1="${CRed}[UNKN]${CClear}"
        elif [ "$diffwan1txbytes" -ge 0 ] && [ "$diffwan1txbytes" -le "$lowutilspdup" ]
        then
          WAN1TX1="${CGreen}[$WAN1BWTX]${CClear}"
        elif [ "$diffwan1txbytes" -gt "$lowutilspdup" ] && [ "$diffwan1txbytes" -le "$medutilspdup" ]
        then
          WAN1TX1="${CYellow}[$WAN1BWTX]${CClear}"
        elif [ "$diffwan1txbytes" -gt "$medutilspdup" ]
        then
          WAN1TX1="${CRed}[$WAN1BWTX]${CClear}"
        fi

        WAN1TPRX="$(printf '%4s' "$thruwan1rxbytes")"
        if [ -z "$thruwan1rxbytes" ] || [ "$thruwan1rxbytes" = "" ] || [ "$thruwan1rxbytes" -lt 0 ]
        then
          WAN1RX2="${CRed}[UNKN]${CClear}"
        elif [ "$thruwan1rxbytes" -ge 0 ] && [ "$thruwan1rxbytes" -le "$lowutilspd" ]
        then
          WAN1RX2="${CGreen}[$WAN1TPRX]${CClear}"
        elif [ "$thruwan1rxbytes" -gt "$lowutilspd" ] && [ "$thruwan1rxbytes" -le "$medutilspd" ]
        then
          WAN1RX2="${CYellow}[$WAN1TPRX]${CClear}"
        elif [ "$thruwan1rxbytes" -gt "$medutilspd" ]
        then
          WAN1RX2="${CRed}[$WAN1TPRX]${CClear}"
        fi

        WAN1TPTX="$(printf '%4s' "$thruwan1txbytes")"
        if [ -z "$thruwan1txbytes" ] || [ "$thruwan1txbytes" = "" ] || [ "$thruwan1txbytes" -lt 0 ]
        then
          WAN1TX2="${CRed}[UNKN]${CClear}"
        elif [ "$thruwan1txbytes" -ge 0 ] && [ "$thruwan1txbytes" -le "$lowutilspdup" ]
        then
          WAN1TX2="${CGreen}[$WAN1TPTX]${CClear}"
        elif [ "$thruwan1txbytes" -gt "$lowutilspdup" ] && [ "$thruwan1txbytes" -le "$medutilspdup" ]
        then
          WAN1TX2="${CYellow}[$WAN1TPTX]${CClear}"
        elif [ "$thruwan1txbytes" -gt "$medutilspdup" ]
        then
          WAN1TX2="${CRed}[$WAN1TPTX]${CClear}"
        fi

        if [ "$WCNT" -ge 1 ]; then
          wan1status="${CRed}[$WCNT]${CClear}"
          wan1health="${CRed}[FAIL]${CClear}"
        else
          wan1status="${CGreen}[X]${CClear}"
          wan1health="${CGreen}[ OK ]${CClear}"
        fi

        if [ "$WAN1PING" = "[FAILOVER]" ]
        then
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN1${CClear} | $wan1status | "
           printf "%-6s" "${WAN1IFNAME:0:6}"
           if [ "$bwdisp" = "1" ]; then
             echo -e " | $wan1health | Failover     | $WAN1IP | $WAN1PING | $WAN1RX1 | $WAN1TX1 | $WAN1CITY: $uptimeStr"
           else
             echo -e " | $wan1health | Failover     | $WAN1IP | $WAN1PING | $WAN1RX2 | $WAN1TX2 | $WAN1CITY: $uptimeStr"
           fi
        else
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN1${CClear} | $wan1status | "
           printf "%-6s" "$WAN1IFNAME"
           if [ "$bwdisp" = "1" ]; then
             echo -e " | $wan1health | ${CGreen}Active${CClear}       | $WAN1IP | $WAN1PING | $WAN1RX1 | $WAN1TX1 | $WAN1CITY: $uptimeStr"
           else
             echo -e " | $wan1health | ${CGreen}Active${CClear}       | $WAN1IP | $WAN1PING | $WAN1RX2 | $WAN1TX2 | $WAN1CITY: $uptimeStr"
           fi
        fi
     else
        echo -e "${InvDkGray}${CWhite}  WAN1${CClear} | ${CGreen}[X]${CClear} | ${CDkGray}[n/a]${CClear}  | ${CDkGray}[n/a ]${CClear} | Inactive     |           ${CDkGray}[n/a]${CClear} |      ${CDkGray}[n/a]${CClear} | ${CDkGray}[n/a ]${CClear} | ${CDkGray}[n/a ]${CClear} | ${CDkGray}[n/a]${CClear}"
     fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function was "borrowed" graciously from @dave14305 from his FlexQoS script to determine the active WAN connection.
# Thanks much for your troubleshooting help as we tackled how to best derive the active WAN interface, Dave!

get_wan_setting()
{
  local varname varval
  varname="${1}"
  prefixes="wan0_ wan1_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"
}

# Separated these out to get the ifname for a dual-wan/failover situation where both WAN connections are on
get_wan_setting0()
{
  local varname varval
  varname="${1}"
  prefixes="wan0_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"
}

# Separated these out to get the ifname for a dual-wan/failover situation where both WAN connections are on
get_wan_setting1()
{
  local varname varval
  varname="${1}"
  prefixes="wan1_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"
}

# -------------------------------------------------------------------------------------------------------------------------
# These functions grab the difference between WAN, OVPN and WG connection stats and calculate Mbps

getifacestats()
{

  if [ $loopexit -eq 1 ]
  then
    loopexit=0
    return
  else
    echo $(date +%s) > "/jffs/addons/vpnmon-r3.d/vr3start.txt"
  fi

  if [ ! -z "$WAN0IFNAME" ]
  then
    oldwan0rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN0IFNAME/statistics/rx_bytes)"
    oldwan0txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN0IFNAME/statistics/tx_bytes)"
  fi

  if [ ! -z "$WAN1IFNAME" ]
  then
    oldwan1rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN1IFNAME/statistics/rx_bytes)"
    oldwan1txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN1IFNAME/statistics/tx_bytes)"
  fi

  if [ "$availableslots" = "1 2" ]
  then
    state1="$(_VPN_GetClientState_ 1)"
    state2="$(_VPN_GetClientState_ 2)"
    state3=0
    state4=0
    state5=0
    wgstate1=0
    wgstate2=0
    wgstate3=0
    wgstate4=0
    wgstate5=0
  elif [ "$availableslots" = "1 2 3 4 5" ]
  then
    state1="$(_VPN_GetClientState_ 1)"
    state2="$(_VPN_GetClientState_ 2)"
    state3="$(_VPN_GetClientState_ 3)"
    state4="$(_VPN_GetClientState_ 4)"
    state5="$(_VPN_GetClientState_ 5)"
    wgstate1="$(_WG_GetClientState_ 1)"
    wgstate2="$(_WG_GetClientState_ 2)"
    wgstate3="$(_WG_GetClientState_ 3)"
    wgstate4="$(_WG_GetClientState_ 4)"
    wgstate5="$(_WG_GetClientState_ 5)"
  fi

  if [ "$state1" -eq 2 ]; then
    oldvpn1txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client1/status 2>/dev/null)
    oldvpn1rxbytes="$(echo $oldvpn1txrxbytes | cut -d' ' -f1)"
    oldvpn1txbytes="$(echo $oldvpn1txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn1rxbytes ]; then oldvpn1rxbytes=0; fi
    if [ -z $oldvpn1txbytes ]; then oldvpn1txbytes=0; fi
  fi

  if [ "$state2" -eq 2 ]; then
    oldvpn2txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client2/status 2>/dev/null)
    oldvpn2rxbytes="$(echo $oldvpn2txrxbytes | cut -d' ' -f1)"
    oldvpn2txbytes="$(echo $oldvpn2txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn2rxbytes ]; then oldvpn2rxbytes=0; fi
    if [ -z $oldvpn2txbytes ]; then oldvpn2txbytes=0; fi
  fi

  if [ "$state3" -eq 2 ]; then
    oldvpn3txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client3/status 2>/dev/null)
    oldvpn3rxbytes="$(echo $oldvpn3txrxbytes | cut -d' ' -f1)"
    oldvpn3txbytes="$(echo $oldvpn3txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn3rxbytes ]; then oldvpn3rxbytes=0; fi
    if [ -z $oldvpn3txbytes ]; then oldvpn3txbytes=0; fi
  fi

  if [ "$state4" -eq 2 ]; then
    oldvpn4txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client4/status 2>/dev/null)
    oldvpn4rxbytes="$(echo $oldvpn4txrxbytes | cut -d' ' -f1)"
    oldvpn4txbytes="$(echo $oldvpn4txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn4rxbytes ]; then oldvpn4rxbytes=0; fi
    if [ -z $oldvpn4txbytes ]; then oldvpn4txbytes=0; fi
  fi

  if [ "$state5" -eq 2 ]; then
    oldvpn5txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client5/status 2>/dev/null)
    oldvpn5rxbytes="$(echo $oldvpn5txrxbytes | cut -d' ' -f1)"
    oldvpn5txbytes="$(echo $oldvpn5txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn5rxbytes ]; then oldvpn5rxbytes=0; fi
    if [ -z $oldvpn5txbytes ]; then oldvpn5txbytes=0; fi
  fi

  if [ "$wgstate1" -eq 2 ]; then
    oldwg1txrxbytes=$(wg show wgc1 transfer)
    oldwg1rxbytes="$(echo $oldwg1txrxbytes | cut -d' ' -f2)"
    oldwg1txbytes="$(echo $oldwg1txrxbytes | cut -d' ' -f3)"
    if [ -z $oldwg1rxbytes ] || [ $oldwg1rxbytes -le 0 ]; then oldwg1rxbytes=0; fi
    if [ -z $oldwg1txbytes ] || [ $oldwg1txbytes -le 0 ]; then oldwg1txbytes=0; fi
  fi

  if [ "$wgstate2" -eq 2 ]; then
    oldwg2txrxbytes=$(wg show wgc2 transfer)
    oldwg2rxbytes="$(echo $oldwg2txrxbytes | cut -d' ' -f2)"
    oldwg2txbytes="$(echo $oldwg2txrxbytes | cut -d' ' -f3)"
    if [ -z $oldwg2rxbytes ] || [ $oldwg2rxbytes -le 0 ]; then oldwg2rxbytes=0; fi
    if [ -z $oldwg2txbytes ] || [ $oldwg2txbytes -le 0 ]; then oldwg2txbytes=0; fi
  fi

  if [ "$wgstate3" -eq 2 ]; then
    oldwg3txrxbytes=$(wg show wgc3 transfer)
    oldwg3rxbytes="$(echo $oldwg3txrxbytes | cut -d' ' -f2)"
    oldwg3txbytes="$(echo $oldwg3txrxbytes | cut -d' ' -f3)"
    if [ -z $oldwg3rxbytes ] || [ $oldwg3rxbytes -le 0 ]; then oldwg3rxbytes=0; fi
    if [ -z $oldwg3txbytes ] || [ $oldwg3txbytes -le 0 ]; then oldwg3txbytes=0; fi
  fi

  if [ "$wgstate4" -eq 2 ]; then
    oldwg4txrxbytes=$(wg show wgc4 transfer)
    oldwg4rxbytes="$(echo $oldwg4txrxbytes | cut -d' ' -f2)"
    oldwg4txbytes="$(echo $oldwg4txrxbytes | cut -d' ' -f3)"
    if [ -z $oldwg4rxbytes ] || [ $oldwg4rxbytes -le 0 ]; then oldwg4rxbytes=0; fi
    if [ -z $oldwg4txbytes ] || [ $oldwg4txbytes -le 0 ]; then oldwg4txbytes=0; fi
  fi

  if [ "$wgstate5" -eq 2 ]; then
    oldwg5txrxbytes=$(wg show wgc5 transfer)
    oldwg5rxbytes="$(echo $oldwg5txrxbytes | cut -d' ' -f2)"
    oldwg5txbytes="$(echo $oldwg5txrxbytes | cut -d' ' -f3)"
    if [ -z $oldwg5rxbytes ] || [ $oldwg5rxbytes -le 0 ]; then oldwg5rxbytes=0; fi
    if [ -z $oldwg5txbytes ] || [ $oldwg5txbytes -le 0 ]; then oldwg5txbytes=0; fi
  fi

}

calcifacestats()
{

  if [ "$resetifacestatsswitch" -eq 1 ]
  then
    resetifacestatsswitch=0
    return
  fi

  if [ $loopexit -eq 1 ]
  then
    return
  fi

  if [ -f "/jffs/addons/vpnmon-r3.d/vr3start.txt" ]
  then
    timerstart=$(cat "/jffs/addons/vpnmon-r3.d/vr3start.txt")
    timernow=$(date +%s)
    timerdiff=$((timernow-timerstart))
    if [ $timerdiff -gt $timerloop ]
    then
      newtimer=$timerdiff
    else
      newtimer=$timerloop
    fi
  else
    newtimer=$timerloop
  fi

  if [ ! -z "$WAN0IFNAME" ]
  then
    newwan0rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN0IFNAME/statistics/rx_bytes)"
    newwan0txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN0IFNAME/statistics/tx_bytes)"
    diffwan0rxbytes=$(awk -v new=$newwan0rxbytes -v old=$oldwan0rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwan0txbytes=$(awk -v new=$newwan0txbytes -v old=$oldwan0txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwan0rxbytes=$(awk -v new=$newwan0rxbytes -v old=$oldwan0rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwan0txbytes=$(awk -v new=$newwan0txbytes -v old=$oldwan0txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  fi

  if [ ! -z "$WAN1IFNAME" ]
  then
    newwan1rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN1IFNAME/statistics/rx_bytes)"
    newwan1txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WAN1IFNAME/statistics/tx_bytes)"
    diffwan1rxbytes=$(awk -v new=$newwan1rxbytes -v old=$oldwan1rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwan1txbytes=$(awk -v new=$newwan1txbytes -v old=$oldwan1txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwan1rxbytes=$(awk -v new=$newwan1rxbytes -v old=$oldwan1rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwan1txbytes=$(awk -v new=$newwan1txbytes -v old=$oldwan1txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  fi

  if [ "$availableslots" = "1 2" ]
  then
    state1="$(_VPN_GetClientState_ 1)"
    state2="$(_VPN_GetClientState_ 2)"
  elif [ "$availableslots" = "1 2 3 4 5" ]
  then
    state1="$(_VPN_GetClientState_ 1)"
    state2="$(_VPN_GetClientState_ 2)"
    state3="$(_VPN_GetClientState_ 3)"
    state4="$(_VPN_GetClientState_ 4)"
    state5="$(_VPN_GetClientState_ 5)"
    wgstate1="$(_WG_GetClientState_ 1)"
    wgstate2="$(_WG_GetClientState_ 2)"
    wgstate3="$(_WG_GetClientState_ 3)"
    wgstate4="$(_WG_GetClientState_ 4)"
    wgstate5="$(_WG_GetClientState_ 5)"
  fi

  if [ "$state1" -eq 2 ]; then
    newvpn1txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client1/status 2>/dev/null)
    newvpn1rxbytes="$(echo $newvpn1txrxbytes | cut -d' ' -f1)"
    newvpn1txbytes="$(echo $newvpn1txrxbytes | cut -d' ' -f2)"
    if [ -z $newvpn1rxbytes ]; then newvpn1rxbytes=0; fi
    if [ -z $newvpn1txbytes ]; then newvpn1txbytes=0; fi
    diffvpn1rxbytes=$(awk -v new=$newvpn1rxbytes -v old=$oldvpn1rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffvpn1txbytes=$(awk -v new=$newvpn1txbytes -v old=$oldvpn1txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruvpn1rxbytes=$(awk -v new=$newvpn1rxbytes -v old=$oldvpn1rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruvpn1txbytes=$(awk -v new=$newvpn1txbytes -v old=$oldvpn1txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffvpn1rxbytes=""
    diffvpn1txbytes=""
    thruvpn1rxbytes=""
    thruvpn1txbytes=""
  fi

  if [ "$state2" -eq 2 ]; then
    newvpn2txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client2/status 2>/dev/null)
    newvpn2rxbytes="$(echo $newvpn2txrxbytes | cut -d' ' -f1)"
    newvpn2txbytes="$(echo $newvpn2txrxbytes | cut -d' ' -f2)"
    if [ -z $newvpn2rxbytes ]; then newvpn2rxbytes=0; fi
    if [ -z $newvpn2txbytes ]; then newvpn2txbytes=0; fi
    diffvpn2rxbytes=$(awk -v new=$newvpn2rxbytes -v old=$oldvpn2rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffvpn2txbytes=$(awk -v new=$newvpn2txbytes -v old=$oldvpn2txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruvpn2rxbytes=$(awk -v new=$newvpn2rxbytes -v old=$oldvpn2rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruvpn2txbytes=$(awk -v new=$newvpn2txbytes -v old=$oldvpn2txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffvpn2rxbytes=""
    diffvpn2txbytes=""
    thruvpn2rxbytes=""
    thruvpn2txbytes=""
  fi

  if [ "$state3" -eq 2 ]; then
    newvpn3txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client3/status 2>/dev/null)
    newvpn3rxbytes="$(echo $newvpn3txrxbytes | cut -d' ' -f1)"
    newvpn3txbytes="$(echo $newvpn3txrxbytes | cut -d' ' -f2)"
    if [ -z $newvpn3rxbytes ]; then newvpn3rxbytes=0; fi
    if [ -z $newvpn3txbytes ]; then newvpn3txbytes=0; fi
    diffvpn3rxbytes=$(awk -v new=$newvpn3rxbytes -v old=$oldvpn3rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffvpn3txbytes=$(awk -v new=$newvpn3txbytes -v old=$oldvpn3txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruvpn3rxbytes=$(awk -v new=$newvpn3rxbytes -v old=$oldvpn3rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruvpn3txbytes=$(awk -v new=$newvpn3txbytes -v old=$oldvpn3txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffvpn3rxbytes=""
    diffvpn3txbytes=""
    thruvpn3rxbytes=""
    thruvpn3txbytes=""
  fi

  if [ "$state4" -eq 2 ]; then
    newvpn4txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client4/status 2>/dev/null)
    newvpn4rxbytes="$(echo $newvpn4txrxbytes | cut -d' ' -f1)"
    newvpn4txbytes="$(echo $newvpn4txrxbytes | cut -d' ' -f2)"
    if [ -z $newvpn4rxbytes ]; then newvpn4rxbytes=0; fi
    if [ -z $newvpn4txbytes ]; then newvpn4txbytes=0; fi
    diffvpn4rxbytes=$(awk -v new=$newvpn4rxbytes -v old=$oldvpn4rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffvpn4txbytes=$(awk -v new=$newvpn4txbytes -v old=$oldvpn4txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruvpn4rxbytes=$(awk -v new=$newvpn4rxbytes -v old=$oldvpn4rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruvpn4txbytes=$(awk -v new=$newvpn4txbytes -v old=$oldvpn4txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffvpn4rxbytes=""
    diffvpn4txbytes=""
    thruvpn4rxbytes=""
    thruvpn4txbytes=""
  fi

  if [ "$state5" -eq 2 ]; then
    newvpn5txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client5/status 2>/dev/null)
    newvpn5rxbytes="$(echo $newvpn5txrxbytes | cut -d' ' -f1)"
    newvpn5txbytes="$(echo $newvpn5txrxbytes | cut -d' ' -f2)"
    if [ -z $newvpn5rxbytes ]; then newvpn5rxbytes=0; fi
    if [ -z $newvpn5txbytes ]; then newvpn5txbytes=0; fi
    diffvpn5rxbytes=$(awk -v new=$newvpn5rxbytes -v old=$oldvpn5rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffvpn5txbytes=$(awk -v new=$newvpn5txbytes -v old=$oldvpn5txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruvpn5rxbytes=$(awk -v new=$newvpn5rxbytes -v old=$oldvpn5rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruvpn5txbytes=$(awk -v new=$newvpn5txbytes -v old=$oldvpn5txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffvpn5rxbytes=""
    diffvpn5txbytes=""
    thruvpn5rxbytes=""
    thruvpn5txbytes=""
  fi

  if [ "$wgstate1" -eq 2 ]; then
    newwg1txrxbytes=$(wg show wgc1 transfer)
    newwg1rxbytes="$(echo $newwg1txrxbytes | cut -d' ' -f2)"
    newwg1txbytes="$(echo $newwg1txrxbytes | cut -d' ' -f3)"
    if [ -z $newwg1rxbytes ] || [ $newwg1rxbytes -le 0 ]; then newwg1rxbytes=0; fi
    if [ -z $newwg1txbytes ] || [ $newwg1txbytes -le 0 ]; then newwg1txbytes=0; fi
    diffwg1rxbytes=$(awk -v new=$newwg1rxbytes -v old=$oldwg1rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwg1txbytes=$(awk -v new=$newwg1txbytes -v old=$oldwg1txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwg1rxbytes=$(awk -v new=$newwg1rxbytes -v old=$oldwg1rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwg1txbytes=$(awk -v new=$newwg1txbytes -v old=$oldwg1txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffwg1rxbytes=""
    diffwg1txbytes=""
    thruwg1rxbytes=""
    thruwg1txbytes=""
  fi

  if [ "$wgstate2" -eq 2 ]; then
    newwg2txrxbytes=$(wg show wgc2 transfer)
    newwg2rxbytes="$(echo $newwg2txrxbytes | cut -d' ' -f2)"
    newwg2txbytes="$(echo $newwg2txrxbytes | cut -d' ' -f3)"
    if [ -z $newwg2rxbytes ] || [ $newwg2rxbytes -le 0 ]; then newwg2rxbytes=0; fi
    if [ -z $newwg2txbytes ] || [ $newwg2txbytes -le 0 ]; then newwg2txbytes=0; fi
    diffwg2rxbytes=$(awk -v new=$newwg2rxbytes -v old=$oldwg2rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwg2txbytes=$(awk -v new=$newwg2txbytes -v old=$oldwg2txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwg2rxbytes=$(awk -v new=$newwg2rxbytes -v old=$oldwg2rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwg2txbytes=$(awk -v new=$newwg2txbytes -v old=$oldwg2txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffwg2rxbytes=""
    diffwg2txbytes=""
    thruwg2rxbytes=""
    thruwg2txbytes=""
  fi

  if [ "$wgstate3" -eq 2 ]; then
    newwg3txrxbytes=$(wg show wgc3 transfer)
    newwg3rxbytes="$(echo $newwg3txrxbytes | cut -d' ' -f2)"
    newwg3txbytes="$(echo $newwg3txrxbytes | cut -d' ' -f3)"
    if [ -z $newwg3rxbytes ] || [ $newwg3rxbytes -le 0 ]; then newwg3rxbytes=0; fi
    if [ -z $newwg3txbytes ] || [ $newwg3txbytes -le 0 ]; then newwg3txbytes=0; fi
    diffwg3rxbytes=$(awk -v new=$newwg3rxbytes -v old=$oldwg3rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwg3txbytes=$(awk -v new=$newwg3txbytes -v old=$oldwg3txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwg3rxbytes=$(awk -v new=$newwg3rxbytes -v old=$oldwg3rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwg3txbytes=$(awk -v new=$newwg3txbytes -v old=$oldwg3txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffwg3rxbytes=""
    diffwg3txbytes=""
    thruwg3rxbytes=""
    thruwg3txbytes=""
  fi

  if [ "$wgstate4" -eq 2 ]; then
    newwg4txrxbytes=$(wg show wgc4 transfer)
    newwg4rxbytes="$(echo $newwg4txrxbytes | cut -d' ' -f2)"
    newwg4txbytes="$(echo $newwg4txrxbytes | cut -d' ' -f3)"
    if [ -z $newwg4rxbytes ] || [ $newwg4rxbytes -le 0 ]; then newwg4rxbytes=0; fi
    if [ -z $newwg4txbytes ] || [ $newwg4txbytes -le 0 ]; then newwg4txbytes=0; fi
    diffwg4rxbytes=$(awk -v new=$newwg4rxbytes -v old=$oldwg4rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwg4txbytes=$(awk -v new=$newwg4txbytes -v old=$oldwg4txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwg4rxbytes=$(awk -v new=$newwg4rxbytes -v old=$oldwg4rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwg4txbytes=$(awk -v new=$newwg4txbytes -v old=$oldwg4txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffwg4rxbytes=""
    diffwg4txbytes=""
    thruwg4rxbytes=""
    thruwg4txbytes=""
  fi

  if [ "$wgstate5" -eq 2 ]; then
    newwg5txrxbytes=$(wg show wgc5 transfer)
    newwg5rxbytes="$(echo $newwg5txrxbytes | cut -d' ' -f2)"
    newwg5txbytes="$(echo $newwg5txrxbytes | cut -d' ' -f3)"
    if [ -z $newwg5rxbytes ] || [ $newwg5rxbytes -le 0 ]; then newwg5rxbytes=0; fi
    if [ -z $newwg5txbytes ] || [ $newwg5txbytes -le 0 ]; then newwg5txbytes=0; fi
    diffwg5rxbytes=$(awk -v new=$newwg5rxbytes -v old=$oldwg5rxbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    diffwg5txbytes=$(awk -v new=$newwg5txbytes -v old=$oldwg5txbytes -v mb=125000 -v lp=$newtimer 'BEGIN{printf "%.0f\n", ((new-old)/mb)/lp}')
    thruwg5rxbytes=$(awk -v new=$newwg5rxbytes -v old=$oldwg5rxbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
    thruwg5txbytes=$(awk -v new=$newwg5txbytes -v old=$oldwg5txbytes -v mb=1000000 'BEGIN{printf "%.0f\n", (new-old)/mb}')
  else
    diffwg5rxbytes=""
    diffwg5txbytes=""
    thruwg5rxbytes=""
    thruwg5txbytes=""
  fi

}

resetifacestats()
{

diffwan0rxbytes=""
diffwan0txbytes=""
diffwan1rxbytes=""
diffwan1txbytes=""
diffvpn1rxbytes=""
diffvpn1txbytes=""
diffvpn2rxbytes=""
diffvpn2txbytes=""
diffvpn3rxbytes=""
diffvpn3txbytes=""
diffvpn4rxbytes=""
diffvpn4txbytes=""
diffvpn5rxbytes=""
diffvpn5txbytes=""
diffwg1rxbytes=""
diffwg1txbytes=""
diffwg2rxbytes=""
diffwg2txbytes=""
diffwg3rxbytes=""
diffwg3txbytes=""
diffwg4rxbytes=""
diffwg4txbytes=""
diffwg5rxbytes=""
diffwg5txbytes=""

thruwan0rxbytes=""
thruwan0txbytes=""
thruwan1rxbytes=""
thruwan1txbytes=""
thruvpn1rxbytes=""
thruvpn1txbytes=""
thruvpn2rxbytes=""
thruvpn2txbytes=""
thruvpn3rxbytes=""
thruvpn3txbytes=""
thruvpn4rxbytes=""
thruvpn4txbytes=""
thruvpn5rxbytes=""
thruvpn5txbytes=""
thruwg1rxbytes=""
thruwg1txbytes=""
thruwg2rxbytes=""
thruwg2txbytes=""
thruwg3rxbytes=""
thruwg3txbytes=""
thruwg4rxbytes=""
thruwg4txbytes=""
thruwg5rxbytes=""
thruwg5txbytes=""

resetifacestatsswitch=1

}

# -------------------------------------------------------------------------------------------------------------------------
# This function displays the operations menu

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-05] ##
##----------------------------------------##
displayopsmenu()
{
    #scheduler colors and indicators
    if [ "$schedule" = "0" ]
    then
       schedtime="${CDkGray}01:00${CClear}"
    elif [ "$schedule" = "1" ]
    then
       schedhrs="$(printf "%02d" "$schedulehrs")"
       schedmin="$(printf "%02d" "$schedulemin")"
       schedtime="${CGreen}$schedhrs:$schedmin${CClear}"
    fi

    #autostart colors and indicators
    if [ "$autostart" = "0" ]; then
       rebootprot="${CDkGray}Disabled${CClear}"
    elif [ "$autostart" = "1" ]; then
       rebootprot="${CGreen}Enabled${CClear}"
    fi

    if [ "$logsize" -eq 0 ]; then
       logSizeStr="${CDkGray}n/a${CClear}"
    else
       logSizeStr="${CGreen}${logsize}${CClear}"
    fi

    if [ -z "$timerloop" ]; then
       timerLoopStr="${CDkGray}n/a${CClear}"
    else
       timerLoopStr="${CGreen}$timerloop sec${CClear}"
    fi

    if [ "$pingreset" -eq 0 ]; then
       pingResetStr="${CDkGray}Disabled${CClear}"
    else
       pingResetStr="${CGreen}$pingreset ms${CClear}"
    fi

    if [ "$amtmemailsuccess" = "0" ] && [ "$amtmemailfailure" = "0" ]; then
       amtmdisp="${CDkGray}Disabled        "
    elif [ "$amtmemailsuccess" = "1" ] && [ "$amtmemailfailure" = "0" ]; then
       amtmdisp="${CGreen}Success         "
    elif [ "$amtmemailsuccess" = "0" ] && [ "$amtmemailfailure" = "1" ]; then
       amtmdisp="${CGreen}Failure         "
    elif [ "$amtmemailsuccess" = "1" ] && [ "$amtmemailfailure" = "1" ]; then
       amtmdisp="${CGreen}Success, Failure"
    else
       amtmdisp="${CDkGray}Disabled        "
    fi

    rldisp=""
    if [ "$amtmemailsuccess" = "1" ] || [ "$amtmemailfailure" = "1" ]
      then
        if [ "$ratelimit" = "0" ]; then
          rldisp="| ${CRed}RL"
        else
          rldisp="| RL: ${CGreen}$ratelimit/h"
        fi
    fi

    recoverdisp="${CClear}Recovery: ${CGreen}${recover}x${CClear}"

    #display operations menu
    if [ "$availableslots" = "1 2" ]
    then
      echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                                                ${CClear}"
      echo -e "${InvGreen} ${CClear} Reset/Reconnect VPN 1:${CGreen}(1)${CClear} 2:${CGreen}(2)${CClear}                               ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu $rldisp${CClear}"
      echo -e "${InvGreen} ${CClear} Stop/Unmonitor  VPN 1:${CGreen}(!)${CClear} 2:${CGreen}(@)${CClear}                               ${InvGreen} ${CClear} ${CGreen}(R)${CClear}eset VPN/WG CRON Time Scheduler: $schedtime"
      echo -e "${InvGreen} ${CClear} Enable/Disable ${CGreen}(M)${CClear}onitored VPN Slots | Time Reset             ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): $logSizeStr"
      echo -e "${InvGreen} ${CClear} Update/Maintain ${CGreen}(V)${CClear}PN Server Lists                            ${InvGreen} ${CClear} ${CGreen}(A)${CClear}utostart VPNMON-R3 on Reboot: $rebootprot"
      echo -e "${InvGreen} ${CClear} Edit/R${CGreen}(U)${CClear}n Server List Automation                             ${InvGreen} ${CClear} ${CGreen}(T)${CClear}imer Loop Check Interval: $timerLoopStr | $recoverdisp"
      echo -e "${InvGreen} ${CClear} AMTM Email Not${CGreen}(I)${CClear}fications: $amtmdisp                  ${InvGreen} ${CClear} ${CGreen}(P)${CClear}ing Maximum Before Reset in ms: $pingResetStr"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""
    elif [ "$availableslots" = "1 2 3 4 5" ]
    then
      echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                                                ${CClear}"
      echo -e "${InvGreen} ${CClear} Reset/Reconnect VPN 1:${CGreen}(1)${CClear} 2:${CGreen}(2)${CClear} 3:${CGreen}(3)${CClear} 4:${CGreen}(4)${CClear} 5:${CGreen}(5)${CClear}             ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu $rldisp${CClear}"
      echo -e "${InvGreen} ${CClear} Stop/Unmonitor  VPN 1:${CGreen}(!)${CClear} 2:${CGreen}(@)${CClear} 3:${CGreen}(#)${CClear} 4:${CGreen}($)${CClear} 5:${CGreen}(%)${CClear}             ${InvGreen} ${CClear} ${CGreen}(R)${CClear}eset VPN/WG CRON Time Scheduler: $schedtime"
      echo -e "${InvGreen} ${CClear} Reset/Reconnect  WG 1:${CGreen}(6)${CClear} 2:${CGreen}(7)${CClear} 3:${CGreen}(8)${CClear} 4:${CGreen}(9)${CClear} 5:${CGreen}(0)${CClear}             ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): $logSizeStr"
      echo -e "${InvGreen} ${CClear} Stop/Unmonitor   WG 1:${CGreen}(^)${CClear} 2:${CGreen}(&)${CClear} 3:${CGreen}(-)${CClear} 4:${CGreen}(+)${CClear} 5:${CGreen}(=)${CClear}             ${InvGreen} ${CClear} ${CGreen}(A)${CClear}utostart VPNMON-R3 on Reboot: $rebootprot"
      echo -e "${InvGreen} ${CClear} Enable/Disable ${CGreen}(M)${CClear}onitored VPN/WG Slots | Time Reset          ${InvGreen} ${CClear} ${CGreen}(T)${CClear}imer Loop Check Interval: $timerLoopStr | $recoverdisp"
      echo -e "${InvGreen} ${CClear} Update/Maintain ${CGreen}(V)${CClear}PN/${CGreen}(W)${CClear}G Server Lists                       ${InvGreen} ${CClear} ${CGreen}(P)${CClear}ing Maximum Before Reset in ms: $pingResetStr"
      echo -e "${InvGreen} ${CClear} Edit/R${CGreen}(U)${CClear}n Server List Automation                             ${InvGreen} ${CClear} AMTM Email Not${CGreen}(I)${CClear}fications: $amtmdisp"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Begin VPNMON-R2 Main Loop
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

# Create the necessary folder/file structure for VPNMON-R3 under /jffs/addons
if [ ! -d "/jffs/addons/vpnmon-r3.d" ]; then
  mkdir -p "/jffs/addons/vpnmon-r3.d"
fi

# Check for and add an alias for VPNMON-R3
if ! grep -F "sh /jffs/scripts/vpnmon-r3.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
  echo "alias vpnmon-r3=\"sh /jffs/scripts/vpnmon-r3.sh\" # added by vpnmon-r3" >> /jffs/configs/profile.add
fi

##-------------------------------------##
## Added by Martinski W. [2024-Oct-05] ##
##-------------------------------------##
_SetUpTimeoutCmdVars_
_SetLAN_HostName_

##-------------------------------------##
## Added by Martinski W. [2024-Nov-04] ##
##-------------------------------------##
ROUTERMODEL="$($timeoutcmd$timeoutsec nvram get odmpid)"
[ -z "$ROUTERMODEL" ] && ROUTERMODEL="$($timeoutcmd$timeoutsec nvram get productid)"
FWVER="$($timeoutcmd$timeoutsec nvram get firmver | tr -d '.')"
BUILDNO="$($timeoutcmd$timeoutsec nvram get buildno)"
EXTENDNO="$($timeoutcmd$timeoutsec nvram get extendno)"
if [ -z "$EXTENDNO" ]; then EXTENDNO=0; fi
FWBUILD="${FWVER}.${BUILDNO}_${EXTENDNO}"

# Check for updates
updatecheck

# Check for an AMTM Auto Update
if [ "$1" = "amtmupdate" ]
then
    shift
    ScriptUpdateFromAMTM "$@"
    exit "$?"
fi

# Check and see if any commandline option is being used
if [ $# -eq 0 ] || [ -z "$1" ]
then
    clear
    exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    exit 0
fi

# Check and see if an invalid commandline option is being used
if [ "$1" = "-h" ] || [ "$1" = "-help" ] || [ "$1" = "-setup" ] || [ "$1" = "-reset" ] || [ "$1" = "-bw" ] || [ "$1" = "-noswitch" ] || [ "$1" = "-screen" ] || [ "$1" = "-now" ] || [ "$1" = "-uowginitstart" ] || [ "$1" = "-uowgnatstart" ]
then
    clear
else
    clear
    echo ""
    echo "VPNMON-R3 v$version"
    echo ""
    echo "Exiting due to invalid commandline options!"
    echo "(run 'vpnmon-r3 -h' for help)"
    echo ""
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the help option is being called
if [ "$1" = "-h" ] || [ "$1" = "-help" ]
then
  clear
  echo ""
  echo "VPNMON-R3 v$version Commandline Option Usage:"
  echo ""
  echo "vpnmon-r3 -h | -help"
  echo "vpnmon-r3 -setup"
  echo "vpnmon-r3 -reset"
  echo "vpnmon-r3 -bw"
  echo "vpnmon-r3 -screen"
  echo "vpnmon-r3 -screen -now"
  echo ""
  echo " -h | -help (this output)"
  echo " -setup (displays the setup menu)"
  echo " -reset (resets vpn connections and exits)"
  echo " -bw (runs vpnmon-r3 in monochrome mode)"
  echo " -screen (runs vpnmon-r3 in screen background)"
  echo " -screen -now (runs vpnmon-r3 in screen background immediately)"
  echo ""
  echo -e "${CClear}"
  exit 0
fi

# Check to see if the Unbound-over-WG init-start action is being called
if [ "$1" = "-uowginitstart" ]
then
    uowginitstart
    exit 0
fi

# Check to see if the Unbound-over-WG nat-start action is being called
if [ "$1" = "-uowgnatstart" ]
then
    uowgnatstart
    exit 0
fi

# Check to see if a second command is being passed to remove color
if [ "$1" = "-bw" ] || { [ $# -gt 1 ] && [ "$2" = "-bw" ] ; }
then
    blackwhite
fi

# Check to see if the -now parameter is being called to bypass the screen timer
if [ $# -gt 1 ] && [ "$2" = "-now" ]
then
    bypassscreentimer=1
fi

# Check to see if the setup option is being called
if [ "$1" = "-setup" ]
then
    logoNM
    vsetup
    exit 0
fi

# Check to see if the reset option is being called
if [ "$1" = "-reset" ]
then
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Reset initiated through -RESET switch" >> $logfile
    vreset
fi

# Check to see if the screen option is being called and run operations normally using the screen utility
if [ "$1" = "-screen" ]
then
    /opt/sbin/screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
    sleep 1
    ScreenSess=$(/opt/sbin/screen -ls | grep "vpnmon-r3" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        if [ "$bypassscreentimer" = "1" ]; then
          /opt/sbin/screen -dmS "vpnmon-r3" $apppath -noswitch
          sleep 1
          /opt/sbin/screen -r vpnmon-r3
        else
          clear
          echo -e "${CClear}Executing ${CGreen}VPNMON-R3 v$version${CClear} using the SCREEN utility..."
          echo ""
          echo -e "${CClear}IMPORTANT:"
          echo -e "${CClear}In order to keep VPNMON-R3 running in the background,"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          /opt/sbin/screen -dmS "vpnmon-r3" $apppath -noswitch
          sleep 5
          /opt/sbin/screen -r vpnmon-r3
          exit 0
        fi
      else
        if [ "$bypassscreentimer" = "1" ]; then
          sleep 1
        else
          clear
          echo -e "${CClear}Connecting to existing ${CGreen}VPNMON-R3 v$version${CClear} SCREEN session...${CClear}"
          echo ""
          echo -e "${CClear}IMPORTANT:${CClear}"
          echo -e "${CClear}In order to keep VPNMON-R3 running in the background,${CClear}"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          echo -e "${CClear}Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          spinner 5
        fi
      fi
    /opt/sbin/screen -dr $ScreenSess
    exit 0
fi

# Check to see if the noswitch option is being called
if [ "$1" = "-noswitch" ]
then
    clear #last switch before the main program starts
    firstrun=1

    # Clean up lockfile and other files
    rm -f $lockfile >/dev/null 2>&1
    rm -f /jffs/addons/vpnmon-r3.d/vr3start.txt >/dev/null 2>&1

    if [ ! -f "$config" ] && [ ! -f "/opt/bin/timeout" ] && [ ! -f "/opt/sbin/screen" ] && [ ! -f "/opt/bin/jq" ]
    then
      echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3 -setup' first.${CClear}"
      echo ""
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 is not configured. Please run the setup/configuration utility" >> $logfile
      exit 0
    fi
fi

ubsync=""
firstDataCollection=true
resetifacestatsswitch=0

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
while true
do
  _SetUpTimeoutCmdVars_
  _SetLAN_HostName_

  # Grab the VPNMON-R3 config file and read it in
  if [ -f "$config" ]
  then
    source "$config"
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 1
  fi

  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]
  then
    source /jffs/addons/vpnmon-r3.d/vr3clients.txt
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Client Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 1
  fi

  if [ -f "$dvpnconfig" ]
  then
    source "$dvpnconfig"
  fi

  createconfigs

  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3timers.txt ]
  then
    source /jffs/addons/vpnmon-r3.d/vr3timers.txt
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Timer Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 1
  fi

  #Set variables
  resetvpn=0
  resetwg=0

  #Check to see if a reset is currently underway
  lockcheck

  clear #display the header

  if [ "$hideoptions" = "0" ] && [ "$hideoptions" != "$prevHideOpts" ]
  then
     timerreset=0
     displayopsmenu
  else
     timerreset=0
  fi
  prevHideOpts="$hideoptions"

  tzone="$(date +%Z)"
  tzonechars="${#tzone}"

  if   [ "$tzonechars" = "1" ]; then tzspaces="        ";
  elif [ "$tzonechars" = "2" ]; then tzspaces="       ";
  elif [ "$tzonechars" = "3" ]; then tzspaces="      ";
  elif [ "$tzonechars" = "4" ]; then tzspaces="     ";
  elif [ "$tzonechars" = "5" ]; then tzspaces="    "; fi

  #Display VPNMON-R3 client header
  echo -en "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v"
  printf "%-8s" $version
  echo -e "                      ${CGreen}(S)${CWhite}how/${CGreen}(H)${CWhite}ide Operations Menu ${InvDkGray}            $tzspaces$(date +"%a %b %d, %Y %H:%M:%S %Z %z") ${CClear}"

  #Display VPNMON-R2 Found Warning
  if [ -f /jffs/scripts/vpnmon-r2.sh ]; then
    echo -e "${InvYellow} ${InvRed}${CWhite} VPNMON-R2 Install Detected. Support and availability for R2 is being sunset. Press (X) for Uninstall Menu.   ${CClear}"
  fi

  #Display VPNMON-R3 Update Notifications
  if [ "$UpdateNotify" != "0" ]; then echo -e "$UpdateNotify\n"; else echo -e "${CClear}"; fi

  #If WAN Monitoring is enabled, test WAN connection and show the following grid
  if [ "$monitorwan" = "1" ] && [ "$firstrun" = "1" ]
  then
     #Check to see if the WAN is up
     checkwan
     firstrun=0
  fi

  if [ "$monitorwan" = "1" ] && [ "$firstrun" = "0" ]
  then
    #Display WAN ports grid
    if [ "$bwdisp" = "1" ]; then
      echo -e "${CClear}  Port | Mon | IFace  | Health | WAN State    | Public WAN IP   | Ping-->WAN | Rx Avg | Tx Avg | City Exit / Uptime"
    else
      echo -e "${CClear}  Port | Mon | IFace  | Health | WAN State    | Public WAN IP   | Ping-->WAN | Rx Ttl | Tx Ttl | City Exit / Uptime"
    fi
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|--------|------------------------------------------"

    #Cycle through the WANCheck connection function to display ping/city info
    wans=0
    for wans in 0 1
    do
        wancheck "$wans"
    done
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|--------|------------------------------------------"
    echo ""
  fi

  if [ "$useovpn" = "1" ]
  then
    echo -e "${InvDkGray} OpenVPN                                                                                                                         ${CClear}"
    echo ""
    #Display VPN client slot grid
    if [ "$unboundclient" != "0" ]; then
      if [ "$bwdisp" = "1" ]; then
        echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | Rx Avg | Tx Avg | City Exit / Time Connected / UB"
      else
        echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | Rx Ttl | Tx Ttl | City Exit / Time Connected / UB"
      fi
    else
      if [ "$bwdisp" = "1" ]; then
        echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | Rx Avg | Tx Avg | City Exit / Time Connected"
      else
        echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | Rx Ttl | Tx Ttl | City Exit / Time Connected"
      fi
    fi
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|--------|------------------------------------------"

    if "$firstDataCollection" ; then printf "\r\033[0K${InvYellow} ${CClear} Please wait..." ; sleep 1 ; fi

    i=0
    for i in $availableslots #loop through the VPN slots
    do
        #Set variables
        citychange=""
        ubsync=""
        vpnrx1=""
        vpntx1=""
        vpnrx2=""
        vpntx2=""

        #determine if the slot is monitored#
        if [ "$((VPN$i))" = "1" ]; then
           monitored="${CGreen}[X]${CClear}"
        else
           monitored="[ ]"
        fi

        #determine the vpn state, and if connected, get vpn IP and city
        vpnstate="$(_VPN_GetClientState_ "$i")"

        if [ "$vpnstate" = "0" ]
        then
           vpnstate="Disconnected"
           vpnhealth="${CDkGray}[n/a ]${CClear}"
           vpnindicator="${InvDkGray} ${CClear}"
           vpnip="          ${CDkGray}[n/a]${CClear}"
           vpncity="${CDkGray}[n/a]${CClear}"
           svrping="     ${CDkGray}[n/a]${CClear}"
           vpnrx1="${CDkGray}[n/a ]${CClear}"
           vpntx1="${CDkGray}[n/a ]${CClear}"
           vpnrx2="${CDkGray}[n/a ]${CClear}"
           vpntx2="${CDkGray}[n/a ]${CClear}"
        elif [ "$vpnstate" = "-1" ]
        then
           vpnstate="Error State "
           vpnhealth="${CDkGray}[n/a ]${CClear}"
           vpnindicator="${InvDkGray} ${CClear}"
           vpnip="${CDkGray}          [n/a]${CClear}"
           vpncity="${CDkGray}[n/a]${CClear}"
           svrping="     ${CDkGray}[n/a]${CClear}"
           vpnrx1="${CDkGray}[n/a ]${CClear}"
           vpntx1="${CDkGray}[n/a ]${CClear}"
           vpnrx2="${CDkGray}[n/a ]${CClear}"
           vpntx2="${CDkGray}[n/a ]${CClear}"
        elif [ "$vpnstate" = "1" ]
        then
           vpnstate="Connecting  "
           vpnhealth="${CDkGray}[n/a ]${CClear}"
           vpnindicator="${InvYellow} ${CClear}"
           vpnip="          ${CDkGray}[n/a]${CClear}"
           vpncity="${CDkGray}[n/a]${CClear}"
           svrping="     ${CDkGray}[n/a]${CClear}"
           vpnrx1="${CDkGray}[n/a ]${CClear}"
           vpntx1="${CDkGray}[n/a ]${CClear}"
           vpnrx2="${CDkGray}[n/a ]${CClear}"
           vpntx2="${CDkGray}[n/a ]${CClear}"
        elif [ "$vpnstate" = "2" ]
        then
           vpnstate="${CGreen}Connected${CClear}   "
           checkvpn "$i"
           getvpnip "$i"
           getvpncity "$i"
           if [ -z "$vpnping" ]
           then
               svrping="${CRed}[PING ERR]${CClear}"
               vpnhealth="${CYellow}[UNKN]${CClear}"
               vpnindicator="${InvYellow} ${CClear}"
           else
               ## No need to do left-padding with zeros for alignment ##
               svrping="$(printf "[%8.3f]" "$vpnping")"
           fi
        else
           vpnstate="Unknown     "
           vpnhealth="${CDkGray}[n/a ]${CClear}"
           vpnindicator="${InvDkGray} ${CClear}"
           vpnip="          ${CDkGray}[n/a]${CClear}"
           vpncity="${CDkGray}[n/a]${CClear}"
           svrping="     ${CDkGray}[n/a]${CClear}"
        fi

        #Determine how many server entries are in each of the vpn slot alternate server files#
        if [ -s "/jffs/addons/vpnmon-r3.d/vr3svr$i.txt" ]
        then
            servercnt="$(cat "/jffs/addons/vpnmon-r3.d/vr3svr$i.txt" | wc -l)"
            if [ -z "$servercnt" ] || [ "$servercnt" -lt 1 ]
            then
                servercnt="${CRed}[0000]${CClear}"
            else
                ## No need to do left-padding with zeros for alignment ##
                servercnt="$(printf "[%4d]" "$servercnt")"
            fi
        else
            servercnt="${CRed}[0000]${CClear}"
        fi

        #Calculate connected time for current VPN slot
        if [ $((VPNTIMER$i)) = "0" ] || [ "$((VPN$i))" = "0" ]
        then
          sincelastreset=""
        else
          currtime=$(date +%s)
          timediff=$((currtime-VPNTIMER$i))
          sincelastreset=$(printf ': %dd %02dh:%02dm\n' $(($timediff/86400)) $(($timediff%86400/3600)) $(($timediff%3600/60)))
        fi

        if [ -z "$vpnrx1" ]
        then
          vpnbwrx=""
          tmpvpnslot="diffvpn${i}rxbytes"
          eval currentvpnslot=\$$tmpvpnslot
          vpnbwrx="$(printf '%4s' "$currentvpnslot")"
          if [ -z "$currentvpnslot" ] || [ "$currentvpnslot" = "" ] || [ "$currentvpnslot" -lt 0 ]
          then
            vpnrx1="${CRed}[UNKN]${CClear}"
          elif [ "$currentvpnslot" -ge 0 ] && [ "$currentvpnslot" -le "$lowutilspdup" ]
          then
            vpnrx1="${CGreen}[$vpnbwrx]${CClear}"
          elif [ "$currentvpnslot" -gt "$lowutilspdup" ] && [ "$currentvpnslot" -le "$medutilspdup" ]
          then
            vpnrx1="${CYellow}[$vpnbwrx]${CClear}"
          elif [ "$currentvpnslot" -gt "$medutilspdup" ]
          then
            vpnrx1="${CRed}[$vpnbwrx]${CClear}"
          fi
        fi

        if [ -z "$vpnrx2" ]
        then
          vpntprx=""
          tmpvpntpslot="thruvpn${i}rxbytes"
          eval currentvpntpslot=\$$tmpvpntpslot
          vpntprx="$(printf '%4s' "$currentvpntpslot")"
          if [ -z "$currentvpntpslot" ] || [ "$currentvpntpslot" = "" ] || [ "$currentvpntpslot" -lt 0 ]
          then
            vpnrx2="${CRed}[UNKN]${CClear}"
          elif [ "$currentvpntpslot" -ge 0 ] && [ "$currentvpntpslot" -le "$lowutilspdup" ]
          then
            vpnrx2="${CGreen}[$vpntprx]${CClear}"
          elif [ "$currentvpntpslot" -gt "$lowutilspdup" ] && [ "$currentvpntpslot" -le "$medutilspdup" ]
          then
            vpnrx2="${CYellow}[$vpntprx]${CClear}"
          elif [ "$currentvpntpslot" -gt "$medutilspdup" ]
          then
            vpnrx2="${CRed}[$vpntprx]${CClear}"
          fi
        fi

        if [ -z "$vpntx1" ]
        then
          vpnbwtx=""
          tmpvpnslot="diffvpn${i}txbytes"
          eval currentvpnslot=\$$tmpvpnslot
          vpnbwtx="$(printf '%4s' "$currentvpnslot")"
          if [ -z "$currentvpnslot" ] || [ "$currentvpnslot" = "" ] || [ "$currentvpnslot" -lt 0 ]
          then
            vpntx1="${CRed}[UNKN]${CClear}"
          elif [ "$currentvpnslot" -ge 0 ] && [ "$currentvpnslot" -le "$lowutilspd" ]
          then
            vpntx1="${CGreen}[$vpnbwtx]${CClear}"
          elif [ "$currentvpnslot" -gt "$lowutilspd" ] && [ "$currentvpnslot" -le "$medutilspd" ]
          then
            vpntx1="${CYellow}[$vpnbwtx]${CClear}"
          elif [ "$currentvpnslot" -gt "$medutilspd" ]
          then
            vpntx1="${CRed}[$vpnbwtx]${CClear}"
          fi
        fi

        if [ -z "$vpntx2" ]
        then
          vpntptx=""
          tmpvpntpslot="thruvpn${i}txbytes"
          eval currentvpntpslot=\$$tmpvpntpslot
          vpntptx="$(printf '%4s' "$currentvpntpslot")"
          if [ -z "$currentvpntpslot" ] || [ "$currentvpntpslot" = "" ] || [ "$currentvpntpslot" -lt 0 ]
          then
            vpntx2="${CRed}[UNKN]${CClear}"
          elif [ "$currentvpntpslot" -ge 0 ] && [ "$currentvpntpslot" -le "$lowutilspd" ]
          then
            vpntx2="${CGreen}[$vpntptx]${CClear}"
          elif [ "$currentvpntpslot" -gt "$lowutilspd" ] && [ "$currentvpntpslot" -le "$medutilspd" ]
          then
            vpntx2="${CYellow}[$vpntptx]${CClear}"
          elif [ "$currentvpntpslot" -gt "$medutilspd" ]
          then
            vpntx2="${CRed}[$vpntptx]${CClear}"
          fi
        fi

        if "$firstDataCollection" ; then printf "\r\033[0K" ; firstDataCollection=false ; fi

        # Print the results of all data gathered sofar #
        if [ "$bwdisp" = "1" ]; then
          echo -e "$vpnindicator${InvDkGray}${CWhite} VPN$i${CClear} | $monitored | $servercnt | $vpnhealth | $vpnstate | $vpnip | $svrping | $vpntx1 | $vpnrx1 | $vpncity$sincelastreset $citychange$ubsync"
        else
          echo -e "$vpnindicator${InvDkGray}${CWhite} VPN$i${CClear} | $monitored | $servercnt | $vpnhealth | $vpnstate | $vpnip | $svrping | $vpntx2 | $vpnrx2 | $vpncity$sincelastreset $citychange$ubsync"
        fi

        #if a vpn is monitored and disconnected, try to restart it
        if [ "$((VPN$i))" = "1" ] && [ "$vpnstate" = "Disconnected" ]
        then #reconnect
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$i has disconnected" >> $logfile
          echo ""
          printf "\33[2K\r"

          #Display a standard timer#
          timer=0
          while [ $timer -ne 5 ]
          do
            timer="$((timer+1))"
            preparebar 46 "|"
            progressbarpause $timer 5 "" "s" "Standard"
          done
          printf "\33[2K\r"

          restartvpn $i
          dvpn_on_tunnel_restart "ovpn" "$i";
          sendmessage 1 "VPN Tunnel Disconnected" $i
          restartrouting
          resetspdmerlin
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        fi

        #if a vpn is monitored and in error state, try to restart it
        if [ "$((VPN$i))" = "1" ] && [ "$vpnstate" = "Error State " ]
        then #reconnect
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$i is in an error state and being reconnected" >> $logfile
          echo ""
          printf "\33[2K\r"

          #display a standard timer#
          timer=0
          while [ $timer -ne 5 ]
          do
            timer="$((timer+1))"
            preparebar 46 "|"
            progressbarpause $timer 5 "" "s" "Standard"
            #sleep 1
          done
          printf "\33[2K\r"

          restartvpn $i
          dvpn_on_tunnel_restart "ovpn" "$i";
          sendmessage 1 "VPN Slot In Error State" $i
          restartrouting
          resetspdmerlin
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        fi

        #if a vpn is monitored and not responsive, try to restart it
        if [ "$((VPN$i))" = "1" ] && [ "$resetvpn" != "0" ]
        then #reconnect
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$i is non-responsive and being reconnected" >> $logfile
          echo ""
          printf "\33[2K\r"

          #display a standard timer#
          timer=0
          while [ $timer -ne 5 ]
          do
            timer="$((timer+1))"
            preparebar 46 "|"
            progressbarpause $timer 5 "" "s" "Standard"
            #sleep 1
          done
          printf "\33[2K\r"

          restartvpn $resetvpn
          dvpn_on_tunnel_restart "ovpn" "$resetvpn";
          sendmessage 1 "VPN Slot Is Non-Responsive" $resetvpn
          restartrouting
          resetspdmerlin
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        fi

        if [ "$((VPN$i))" = "1" ]; then
          # if a vpn connection ping is greater than a certain amount, restart it
          maxsvrping=$(awk "BEGIN {printf \"%3.0f\", ${vpnping}}") >/dev/null 2>&1
          MP=$?
          if [ $MP -ne 0 ]; then
            if [ -z "$maxsvrping" ] || [ "$maxsvrping" = "" ]; then
              maxsvrping="Null"
            fi
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$i received invalid PING information. Contents: $maxsvrping" >> $logfile
            maxsvrping=0
          fi
        else
          maxsvrping=0
        fi

        if [ "$pingreset" -gt 0 ]
        then
          if [ "$maxsvrping" -ge "$pingreset" ]
          then
            echo ""
            printf "\33[2K\r"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$i PING exceeds max allowed ($pingreset ms)" >> $logfile
            printf "${CGreen}\r[Maximum PING Exceeded]"
            sleep 3
            printf "\33[2K\r"

            #display a standard timer#
            timer=0
            while [ $timer -ne 5 ]
            do
              timer="$((timer+1))"
              preparebar 46 "|"
              progressbarpause $timer 5 "" "s" "Standard"
              #sleep 1
            done
            printf "\33[2K\r"

            restartvpn $i
            dvpn_on_tunnel_restart "ovpn" "$i";
            sendmessage 1 "VPN Slot Exceeded Max Ping" $i
            restartrouting
            resetspdmerlin
            exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
          fi
        fi

        #Reset variables
        ubsync=""
        sincelastreset=""

    done

    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|--------|------------------------------------------"
    echo ""
  fi

#-----------------Wireguard

  if [ "$availableslots" = "1 2 3 4 5" ] && [ "$usewg" = "1" ]; then

    echo -e "${InvDkGray} Wireguard                                                                                                                       ${CClear}"
    echo ""

    #Display WG client slot grid
    if [ "$unboundwgclient" != "0" ]; then
      if [ "$bwdisp" = "1" ]; then
        echo -e "  Slot | Mon |  Svrs  | Health | WG State     | Public WG IP    | Ping--->WG | Rx Avg | Tx Avg | City Exit / Time Connected / UB"
      else
        echo -e "  Slot | Mon |  Svrs  | Health | WG State     | Public WG IP    | Ping--->WG | Rx Ttl | Tx Ttl | City Exit / Time Connected / UB"
      fi
    else
      if [ "$bwdisp" = "1" ]; then
        echo -e "  Slot | Mon |  Svrs  | Health | WG State     | Public WG IP    | Ping--->WG | Rx Avg | Tx Avg | City Exit / Time Connected"
      else
        echo -e "  Slot | Mon |  Svrs  | Health | WG State     | Public WG IP    | Ping--->WG | Rx Ttl | Tx Ttl | City Exit / Time Connected"
      fi
    fi

    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|--------|------------------------------------------"

    i=0
    for i in $availableslots #loop through the VPN slots
    do
        #Set variables
        wgcitychange=""
        ubsync=""
        wgrx1=""
        wgtx1=""
        wgrx2=""
        wgtx2=""

        #determine if the slot is monitored#
        if [ "$((WG$i))" = "1" ]; then
           wgmonitored="${CGreen}[X]${CClear}"
        else
           wgmonitored="[ ]"
        fi

        #determine the vpn state, and if connected, get vpn IP and city
        wgstate="$(_WG_GetClientState_ "$i")"

        if [ "$wgstate" = "0" ]
        then
           wgstate="Disconnected"
           wghealth="${CDkGray}[n/a ]${CClear}"
           wgindicator="${InvDkGray} ${CClear}"
           wgip="          ${CDkGray}[n/a]${CClear}"
           wgcity="${CDkGray}[n/a]${CClear}"
           wgsvrping="     ${CDkGray}[n/a]${CClear}"
           wgrx1="${CDkGray}[n/a ]${CClear}"
           wgtx1="${CDkGray}[n/a ]${CClear}"
           wgrx2="${CDkGray}[n/a ]${CClear}"
           wgtx2="${CDkGray}[n/a ]${CClear}"
        elif [ "$wgstate" = "2" ]
        then
           wgstate="${CGreen}Connected${CClear}   "
           checkwg "$i"
           getwgip "$i"
           getwgcity "$i"
           if [ -z "$wgping" ]
           then
               wgsvrping="${CRed}[PING ERR]${CClear}"
               wghealth="${CYellow}[UNKN]${CClear}"
               wgindicator="${InvYellow} ${CClear}"
           else
               ## No need to do left-padding with zeros for alignment ##
               wgsvrping="$(printf "[%8.3f]" "$wgping")"
           fi
        else
           wgstate="Unknown     "
           wghealth="${CDkGray}[n/a ]${CClear}"
           wgindicator="${InvDkGray} ${CClear}"
           wgip="          ${CDkGray}[n/a]${CClear}"
           wgcity="${CDkGray}[n/a]${CClear}"
           wgsvrping="     ${CDkGray}[n/a]${CClear}"
           wgrx1="${CDkGray}[n/a ]${CClear}"
           wgtx1="${CDkGray}[n/a ]${CClear}"
           wgrx2="${CDkGray}[n/a ]${CClear}"
           wgtx2="${CDkGray}[n/a ]${CClear}"
        fi

        #Determine how many server entries are in each of the vpn slot alternate server files#
        if [ -s "/jffs/addons/vpnmon-r3.d/vr3wgsvr$i.txt" ]
        then
            wgservercnt="$(cat "/jffs/addons/vpnmon-r3.d/vr3wgsvr$i.txt" | wc -l)"
            if [ -z "$wgservercnt" ] || [ "$wgservercnt" -lt 1 ]
            then
                wgservercnt="${CRed}[0000]${CClear}"
            else
                ## No need to do left-padding with zeros for alignment ##
                wgservercnt="$(printf "[%4d]" "$wgservercnt")"
            fi
        else
            wgservercnt="${CRed}[0000]${CClear}"
        fi

        #Calculate connected time for current VPN slot
        if [ $((WGTIMER$i)) = "0" ] || [ "$((WG$i))" = "0" ]
        then
          wgsincelastreset=""
        else
          wgcurrtime=$(date +%s)
          wgtimediff=$((wgcurrtime-WGTIMER$i))
          wgsincelastreset=$(printf ': %dd %02dh:%02dm\n' $(($wgtimediff/86400)) $(($wgtimediff%86400/3600)) $(($wgtimediff%3600/60)))
        fi

        if [ -z "$wgrx1" ]
        then
          wgbwrx=""
          tmpwgslot="diffwg${i}rxbytes"
          eval currentwgslot=\$$tmpwgslot
          wgbwrx="$(printf '%4s' "$currentwgslot")"
          if [ -z "$currentwgslot" ] || [ "$currentwgslot" = "" ] || [ "$currentwgslot" -lt 0 ]
          then
            wgrx1="${CRed}[UNKN]${CClear}"
          elif [ "$currentwgslot" -ge 0 ] && [ "$currentwgslot" -le "$lowutilspd" ]
          then
            wgrx1="${CGreen}[$wgbwrx]${CClear}"
          elif [ "$currentwgslot" -gt "$lowutilspd" ] && [ "$currentwgslot" -le "$medutilspd" ]
          then
            wgrx1="${CYellow}[$wgbwrx]${CClear}"
          elif [ "$currentwgslot" -gt "$medutilspd" ]
          then
            wgrx1="${CRed}[$wgbwrx]${CClear}"
          fi
        fi

        if [ -z "$wgrx2" ]
        then
          wgtprx=""
          tmpwgtpslot="thruwg${i}rxbytes"
          eval currentwgtpslot=\$$tmpwgtpslot
          wgtprx="$(printf '%4s' "$currentwgtpslot")"
          if [ -z "$currentwgtpslot" ] || [ "$currentwgtpslot" = "" ] || [ "$currentwgtpslot" -lt 0 ]
          then
            wgrx2="${CRed}[UNKN]${CClear}"
          elif [ "$currentwgtpslot" -ge 0 ] && [ "$currentwgtpslot" -le "$lowutilspd" ]
          then
            wgrx2="${CGreen}[$wgtprx]${CClear}"
          elif [ "$currentwgtpslot" -gt "$lowutilspd" ] && [ "$currentwgtpslot" -le "$medutilspd" ]
          then
            wgrx2="${CYellow}[$wgtprx]${CClear}"
          elif [ "$currentwgtpslot" -gt "$medutilspd" ]
          then
            wgrx2="${CRed}[$wgtprx]${CClear}"
          fi
        fi

        if [ -z "$wgtx1" ]
        then
          wgbwtx=""
          tmpwgslot="diffwg${i}txbytes"
          eval currentwgslot=\$$tmpwgslot
          wgbwtx="$(printf '%4s' "$currentwgslot")"
          if [ -z "$currentwgslot" ] || [ "$currentwgslot" = "" ] || [ "$currentwgslot" -lt 0 ]
          then
            wgtx1="${CRed}[UNKN]${CClear}"
          elif [ "$currentwgslot" -ge 0 ] && [ "$currentwgslot" -le "$lowutilspdup" ]
          then
            wgtx1="${CGreen}[$wgbwtx]${CClear}"
          elif [ "$currentwgslot" -gt "$lowutilspdup" ] && [ "$currentwgslot" -le "$medutilspdup" ]
          then
            wgtx1="${CYellow}[$wgbwtx]${CClear}"
          elif [ "$currentwgslot" -gt "$medutilspdup" ]
          then
            wgtx1="${CRed}[$wgbwtx]${CClear}"
          fi
        fi

        if [ -z "$wgtx2" ]
        then
          wgtptx=""
          tmpwgtpslot="thruwg${i}txbytes"
          eval currentwgtpslot=\$$tmpwgtpslot
          wgtptx="$(printf '%4s' "$currentwgtpslot")"
          if [ -z "$currentwgtpslot" ] || [ "$currentwgtpslot" = "" ] || [ "$currentwgtpslot" -lt 0 ]
          then
            wgtx2="${CRed}[UNKN]${CClear}"
          elif [ "$currentwgtpslot" -ge 0 ] && [ "$currentwgtpslot" -le "$lowutilspdup" ]
          then
            wgtx2="${CGreen}[$wgtptx]${CClear}"
          elif [ "$currentwgtpslot" -gt "$lowutilspdup" ] && [ "$currentwgtpslot" -le "$medutilspdup" ]
          then
            wgtx2="${CYellow}[$wgtptx]${CClear}"
          elif [ "$currentwgtpslot" -gt "$medutilspdup" ]
          then
            wgtx2="${CRed}[$wgtptx]${CClear}"
          fi
        fi

        # Print the results of all data gathered sofar #
        if [ "$bwdisp" = "1" ]; then
          echo -e "$wgindicator${InvDkGray}${CWhite} WGC$i${CClear} | $wgmonitored | $wgservercnt | $wghealth | $wgstate | $wgip | $wgsvrping | $wgrx1 | $wgtx1 | $wgcity$wgsincelastreset $wgcitychange$ubsync"
        else
          echo -e "$wgindicator${InvDkGray}${CWhite} WGC$i${CClear} | $wgmonitored | $wgservercnt | $wghealth | $wgstate | $wgip | $wgsvrping | $wgrx2 | $wgtx2 | $wgcity$wgsincelastreset $wgcitychange$ubsync"
        fi

        #if a wg connection is monitored and disconnected, try to restart it
        if [ "$((WG$i))" = "1" ] && [ "$wgstate" = "Disconnected" ]
        then #reconnect
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$i has disconnected" >> $logfile
          echo ""
          printf "\33[2K\r"

          #Display a standard timer#
          timer=0
          while [ $timer -ne 5 ]
          do
            timer="$((timer+1))"
            preparebar 46 "|"
            progressbarpause $timer 5 "" "s" "Standard"
          done
          printf "\33[2K\r"

          restartwg $i
          dvpn_on_tunnel_restart "wg" "$i"
          sendmessage 1 "WG Tunnel Disconnected" $i
          restartrouting
          resetspdmerlin
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        fi

        #if the wg handshake exceeds 200s, try to restart it
        # Inspiration from ZebMcKayHan's WGC Watchdog Script
        if [ "$((WG$i))" = "1" ] && [ "$wgstate" = "Connected" ]
        then
          last_handshake=$(wg show wgc$i latest-handshakes | awk '{print $2}') >/dev/null 2>&1
          if [ ! -z $last_handshake ]
            then
              idle_seconds=$((`date +%s`-${last_handshake}))
              if [ "$idle_seconds" -gt "180" ]
              then #reconnect
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$i handshake exceeded 180s" >> $logfile
                echo ""
                printf "\33[2K\r"

                #Display a standard timer#
                timer=0
                while [ $timer -ne 5 ]
                do
                  timer="$((timer+1))"
                  preparebar 46 "|"
                  progressbarpause $timer 5 "" "s" "Standard"
                done
                printf "\33[2K\r"

                restartwg $i
                dvpn_on_tunnel_restart "wg" "$i"
                sendmessage 1 "WG Handshake Exceeded" $i
                restartrouting
                resetspdmerlin
                exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
              fi
          fi
        fi

        if [ "$((WG$i))" = "1" ]; then
          # if a wg connection ping is greater than a certain amount, restart it
          maxsvrping=$(awk "BEGIN {printf \"%3.0f\", ${wgping}}") >/dev/null 2>&1
          MP=$?
          if [ $MP -ne 0 ]; then
            if [ -z "$maxsvrping" ] || [ "$maxsvrping" = "" ]; then
              maxsvrping="Null"
            fi
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$i received invalid PING information. Contents: $maxsvrping" >> $logfile
            maxsvrping=0
          fi
        else
          maxsvrping=0
        fi

        if [ "$pingreset" -gt 0 ]
        then
          if [ "$maxsvrping" -ge "$pingreset" ]
          then
            echo ""
            printf "\33[2K\r"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$i PING exceeds max allowed ($pingreset ms)" >> $logfile
            printf "${CGreen}\r[Maximum PING Exceeded]"
            sleep 3
            printf "\33[2K\r"

            #display a standard timer#
            timer=0
            while [ $timer -ne 5 ]
            do
              timer="$((timer+1))"
              preparebar 46 "|"
              progressbarpause $timer 5 "" "s" "Standard"
              #sleep 1
            done
            printf "\33[2K\r"

            restartwg $i
            dvpn_on_tunnel_restart "wg" "$i"
            sendmessage 1 "WG Slot Exceeded Max Ping" $i
            restartrouting
            resetspdmerlin
            exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
          fi
        fi

        #if a wg is monitored and not responsive, try to restart it
        if [ "$((WG$i))" = "1" ] && [ "$resetwg" != "0" ]
        then #reconnect
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$i is non-responsive and being reconnected" >> $logfile
          echo ""
          printf "\33[2K\r"

          #display a standard timer#
          timer=0
          while [ $timer -ne 5 ]
          do
            timer="$((timer+1))"
            preparebar 46 "|"
            progressbarpause $timer 5 "" "s" "Standard"
            #sleep 1
          done
          printf "\33[2K\r"

          restartwg $resetwg
          dvpn_on_tunnel_restart "wg" "$resetwg"
          sendmessage 1 "WG Slot Is Non-Responsive" $resetwg
          restartrouting
          resetspdmerlin
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        fi

        #Reset variables
        wgsincelastreset=""

    done

    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|--------|------------------------------------------"
    echo ""
    dvpn_display_status

  #-----------------
  fi

  #display a standard timer#
  timer=0
  lastTimerSec=0
  updateTimer=true

  getifacestats # Grab fresh interface stats

  while [ "$timer" -lt "$timerloop" ]
  do
      if "$updateTimer"
      then
          updateTimer=false
          timer="$((timer+1))"
          lastTimerSec="$(date +%s)"
      fi
      preparebar 46 "|"
      progressbaroverride "$timer" "$timerloop" "" "s" "Standard"
      lockcheck #Check to see if a reset is currently underway
      if [ "$timerreset" = "1" ]; then timer="$timerloop" ; fi

      ## Prevent repeatedly fast key presses from updating the timer ##
      [ "$(date +%s)" -gt "$lastTimerSec" ] && updateTimer=true
  done

  calcifacestats # Grab new stats after the timer completes for comparison

  dvpn_check_and_apply # Check if DoubleVPN is currently intact

  #Check to see if a reset is currently underway
  lockcheck
  prevHideOpts=X

  #if Unbound is active and out of sync, try to restart it
  if [ "$unboundclient" != "0" ] && [ "$ResolverTimer" = "1" ]
  then

    if [ "$useovpn" = "1" ]
      then
        printf "\33[2K\r"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$unboundreset is out of sync with Unbound DNS Resolver" >> $logfile
        printf "${CGreen}\r[Unbound is out of sync]"
        sleep 3
        printf "\33[2K\r"

        #display a standard timer
        timer=0
        while [ $timer -ne 5 ]
        do
          timer="$((timer+1))"
          preparebar 46 "|"
          progressbarpause $timer 5 "" "s" "Standard"
        done
        printf "\33[2K\r"

        restartvpn $unboundreset
        dvpn_on_tunnel_restart "ovpn" "$unboundreset";
        sendmessage 1 "VPN Slot Not Synced With Unbound" $unboundreset
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    fi
  fi

  if [ "$unboundwgclient" != "0" ] && [ "$ResolverTimer" = "1" ]
  then
    if [ "$usewg" = "1" ]
      then
        printf "\33[2K\r"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WGC$unboundreset is out of sync with Unbound DNS Resolver" >> $logfile
        printf "${CGreen}\r[Unbound is out of sync]"
        sleep 3
        printf "\33[2K\r"

        #display a standard timer
        timer=0
        while [ $timer -ne 5 ]
        do
          timer="$((timer+1))"
          preparebar 46 "|"
          progressbarpause $timer 5 "" "s" "Standard"
        done
        printf "\33[2K\r"

        restartwg $unboundreset
        dvpn_on_tunnel_restart "wg" "$unboundreset"
        sendmessage 1 "WG Slot Not Synced With Unbound" $unboundreset
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    fi
  fi

  #Check to see if the WAN is up
  if [ "$monitorwan" = "1" ] && [ "$bypasswancheck" = "0" ]; then
     checkwan
  fi

  firstrun=0

done
echo -e "${CClear}"
exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
