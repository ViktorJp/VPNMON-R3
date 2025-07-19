#!/bin/sh

# VPNMON-R3 v1.5.02a (VPNMON-R3.SH) is an all-in-one script that is optimized to maintain multiple VPN connections and is
# able to provide for the capabilities to randomly reconnect using a specified server list containing the servers of your
# choice. Special care has been taken to ensure that only the VPN connections you want to have monitored are tended to.
# This script will check the health of up to 5 VPN connections on a regular interval to see if monitored VPN conenctions
# are connected, and sends a ping to a host of your choice through each active connection. If it finds that a connection
# has been lost, it will execute a series of commands that will kill that single VPN client, and randomly picks one of
# your specified servers to reconnect to for each VPN client.
# Last Modified: 2025-Jan-01
##########################################################################################

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

#Static Variables - please do not change
version="1.5.02a"                                               # Version tracker
beta=1                                                          # Beta switch
screenshotmode=0                                                # Switch to present bogus info for screenshots
apppath="/jffs/scripts/vpnmon-r3.sh"                            # Static path to the app
logfile="/jffs/addons/vpnmon-r3.d/vpnmon-r3.log"                # Static path to the log
dlverpath="/jffs/addons/vpnmon-r3.d/version.txt"                # Static path to the version file
config="/jffs/addons/vpnmon-r3.d/vpnmon-r3.cfg"                 # Static path to the config file
lockfile="/jffs/addons/vpnmon-r3.d/resetlock.txt"               # Static path to the reset lock file
availableslots="1 2 3 4 5"                                      # Available slots tracker
logsize=2000                                                    # Log file size in rows
timerloop=60                                                    # Timer loop in sec
schedule=0                                                      # Scheduler enable y/n
schedulehrs=1                                                   # Scheduler hours
schedulemin=0                                                   # Scheduler mins
autostart=0                                                     # Auto start on router reboot y/n
unboundclient=0                                                 # Unbound bound to VPN client slot#
ResolverTimer=1                                                 # Timer to give DNS resolver time to settle
vpnping=0                                                       # Tracking VPN Tunnel Pings
refreshserverlists=0                                            # Tracking Automated Custom VPN Server List Reset
monitorwan=0                                                    # Tracking WAN/Dual WAN Monitoring
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

##-------------------------------------##
## Added by Martinski W. [2024-Oct-05] ##
##-------------------------------------##
readonly PING_HOST_Deflt="8.8.8.8"
readonly IPv4octet_RegEx="([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])"
readonly IPv4addrs_RegEx="(${IPv4octet_RegEx}\.){3}${IPv4octet_RegEx}"
LAN_HostName=""
prevHideOpts=X  # Avoid redisplaying the menu options unnecessarily too often #

PINGHOST="$PING_HOST_Deflt"                                     # Ping host

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

promptyn () {   # No defaults, just y or n
  while true; do
    read -p '[y/n]? ' YESNO
      case "$YESNO" in
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
  totalspins=$((spins / 4))
  while [ $spin -le $totalspins ]; do
    for spinchar in / - \\ \|; do
      printf "\r$spinchar"
      sleep 1
    done
    spin=$((spin+1))
  done

  printf "\r"
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
progressbaroverride()
{
  insertspc=" "
  bypasswancheck=0

  _GetPercent_() { printf "%.1f" "$(echo "$1" | awk "{print $1}")" ; }

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
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ "$key_press" ]
  then
      case "$key_press" in
          [1]) echo ""; restartvpn 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [2]) echo ""; restartvpn 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [3]) echo ""; restartvpn 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [4]) echo ""; restartvpn 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [5]) echo ""; restartvpn 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [6]) echo ""; restartwg 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [7]) echo ""; restartwg 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [8]) echo ""; restartwg 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [9]) echo ""; restartwg 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [0]) echo ""; restartwg 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\!]) echo ""; killunmonvpn 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\@]) echo ""; killunmonvpn 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\#]) echo ""; killunmonvpn 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\$]) echo ""; killunmonvpn 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\%]) echo ""; killunmonvpn 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\^]) echo ""; killunmonwg 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\&]) echo ""; killunmonwg 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\-]) echo ""; killunmonwg 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\+]) echo ""; killunmonwg 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\=]) echo ""; killunmonwg 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [Aa]) autostart;;
          [Cc]) vsetup;;
          [Dd]) wgserverlistautomation;;
          [Ee]) logoNMexit; echo -e "${CClear}\n"; exit 0;;
          [Hh]) hideoptions=1 ; [ "$hideoptions" != "$prevHideOpts" ] && timerreset=1 ;;
          [Ii]) amtmevents;;
          [Ll]) vlogs;;
          [Mm]) vpnslots;;
          [Pp]) maxping;;
          [Rr]) schedulevpnreset;;
          [Ss]) hideoptions=0 ; [ "$hideoptions" != "$prevHideOpts" ] && timerreset=1 ;;
          [Tt]) timerloopconfig;;
          [Uu]) vpnserverlistautomation;;
          [Vv]) vpnserverlistmaint;;
          [Ww]) wgserverlistmaint;;
          [Xx]) uninstallr2;;
             *) ;; ##IGNORE INVALID key presses ##
      esac
      bypasswancheck=1
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
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

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
        if promptyn "(y/n): "
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
            [1]) echo ""; restartvpn 1; sendmessage 0 "VPN Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [2]) echo ""; restartvpn 2; sendmessage 0 "VPN Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\!]) echo ""; killunmonvpn 1; sendmessage 0 "VPN Killed" 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [\@]) echo ""; killunmonvpn 2; sendmessage 0 "VPN Killed" 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [Aa]) autostart;;
            [Cc]) vsetup;;
            [Ee]) echo -e "${CClear}\n"; exit 0;;
            [Ii]) amtmevents;;
            [Ll]) vlogs;;
            [Mm]) vpnslots;;
            [Pp]) maxping;;
            [Rr]) schedulevpnreset;;
            [Tt]) timerloopconfig;;
            [Uu]) vpnserverlistautomation;;
            [Vv]) vpnserverlistmaint;;
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
            [1]) echo ""; restartvpn 1; sendmessage 0 "VPN Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [2]) echo ""; restartvpn 2; sendmessage 0 "VPN Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [3]) echo ""; restartvpn 3; sendmessage 0 "VPN Reset" 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [4]) echo ""; restartvpn 4; sendmessage 0 "VPN Reset" 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [5]) echo ""; restartvpn 5; sendmessage 0 "VPN Reset" 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [6]) echo ""; restartwg 1; sendmessage 0 "WG Reset" 1; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [7]) echo ""; restartwg 2; sendmessage 0 "WG Reset" 2; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [8]) echo ""; restartwg 3; sendmessage 0 "WG Reset" 3; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [9]) echo ""; restartwg 4; sendmessage 0 "WG Reset" 4; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
            [0]) echo ""; restartwg 5; sendmessage 0 "WG Reset" 5; restartrouting; resetspdmerlin; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
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
            [Aa]) autostart;;
            [Cc]) vsetup;;
            [Ee]) echo -e "${CClear}\n"; exit 0;;
            [Ii]) amtmevents;;
            [Ll]) vlogs;;
            [Mm]) vpnslots;;
            [Pp]) maxping;;
            [Rr]) schedulevpnreset;;
            [Tt]) timerloopconfig;;
            [Uu]) vpnserverlistautomation;;
            [Vv]) vpnserverlistmaint;;
            [Ww]) wgserverlistmaint;;
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

  # Fix older versions using incorrect client slots
  if [ "$availableslots" = "1 2 3" ]
  then
    availableslots="1 2"
    rm -f /jffs/addons/vpnmon-r3.d/vr3clients.txt
    rm -f /jffs/addons/vpnmon-r3.d/vr3timers.txt
    saveconfig
  fi

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
          if promptyn " (y/n): "
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
  if [ "$unboundclient" -eq 0 ]; then
     unboundclientexp="Disabled"
  else
     unboundclientexp="Enabled, VPN$unboundclient"
  fi

  if [ "$refreshserverlists" -eq 0 ]; then
     refreshserverlistsdisp="Disabled"
  else
     refreshserverlistsdisp="Enabled"
  fi

  if [ "$monitorwan" -eq 0 ]; then
     monitorwandisp="Disabled"
  else
     monitorwandisp="Enabled"
  fi

  if [ "$updateskynet" -eq 0 ]; then
     updateskynetdisp="Disabled"
  else
     updateskynetdisp="Enabled"
  fi

  if [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "0" ]; then
     amtmemailsuccfaildisp="Disabled"
  elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "0" ]; then
     amtmemailsuccfaildisp="Success"
  elif [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "1" ]; then
     amtmemailsuccfaildisp="Failure"
  elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "1" ]; then
     amtmemailsuccfaildisp="Success, Failure"
  else
     amtmemailsuccfaildisp="Disabled"
  fi

  if [ "$rstspdmerlin" -eq 0 ]; then
     rstspdmerlindisp="Disabled"
  else
     rstspdmerlindisp="Enabled"
  fi

  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 Configuration Options                                                       ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to modify certain${CClear}"
  echo -e "${InvGreen} ${CClear} customizable parameters that affect the operation of this script.${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Number of VPN Client Slots available         : ${CGreen}$availableslots"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Custom PING host to determine VPN health     : ${CGreen}$PINGHOST"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Custom Event Log size (rows)                 : ${CGreen}$logsize"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : Unbound DNS Lookups over VPN Integration     : ${CGreen}$unboundclientexp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Refresh Custom Server Lists on -RESET Switch : ${CGreen}$refreshserverlistsdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(6)${CClear} : Provide additional WAN/Dual WAN monitoring   : ${CGreen}$monitorwandisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(7)${CClear} : Whitelist VPN Server IP Lists in Skynet      : ${CGreen}$updateskynetdisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(8)${CClear} : AMTM Email Notifications on Success/Failure  : ${CGreen}$amtmemailsuccfaildisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(9)${CClear} : Reset spdMerlin Interfaces on VPN Reset      : ${CGreen}$rstspdmerlindisp"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-9, e=Exit): " SelectSlot
    case $SelectSlot in
      1)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Number of VPN Client Slots Available on Router                                        ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate how many VPN client slots your router is configured with. Certain${CClear}"
        echo -e "${InvGreen} ${CClear} older model routers (RT-AC68U) can only handle a maximum of 2 client slots, while${CClear}"
        echo -e "${InvGreen} ${CClear} the vast majority of newer models can handle 5."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = 5 VPN client slots)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}$availableslots${CClear}" ; echo
        read -p "Please enter value (2 or 5)? (e=Exit): " newAvailableSlots
        if [ "$newAvailableSlots" = "2" ]
        then
            availableslots="1 2"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            rm -f /jffs/addons/vpnmon-r3.d/vr3clients.txt
            rm -f /jffs/addons/vpnmon-r3.d/vr3timers.txt
            saveconfig
            createconfigs
        elif [ "$newAvailableSlots" = "5" ]
        then
            availableslots="1 2 3 4 5"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
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
            [ "$availableslots" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            rm -f /jffs/addons/vpnmon-r3.d/vr3clients.txt
            rm -f /jffs/addons/vpnmon-r3.d/vr3timers.txt
            saveconfig
            createconfigs
        fi
      ;;

      2)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom PING Host (to determine VPN health)                                            ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate which host you want to PING in order to determine VPN Client health.${CClear}"
        echo -e "${InvGreen} ${CClear} By default, the script will ping $PING_HOST_Deflt (Google DNS) as it's reliable, fairly${CClear}"
        echo -e "${InvGreen} ${CClear} standard, and typically available globally. You can change this depending on your"
        echo -e "${InvGreen} ${CClear} local access and connectivity situation."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = ${PING_HOST_Deflt})${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo
        echo -e "${CClear}Current: ${CGreen}${PINGHOST}${CClear}" ; echo
        read -p "Please enter valid IPv4 address? (e=Exit): " newPingHost
        if [ "$newPingHost" = "e" ]
        then
            echo -e "\n[Exiting]"; sleep 2
        elif [ -n "$newPingHost" ] && echo "$newPingHost" | grep -qE "^${IPv4addrs_RegEx}$"
        then
            PINGHOST="$newPingHost"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New custom PING host entered: $PINGHOST" >> $logfile
            saveconfig
        else
            previousValue="$PINGHOST"
            PINGHOST="${PINGHOST:=$PING_HOST_Deflt}"
            [ "$PINGHOST" != "$previousValue" ] && \
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New custom PING host entered: $PINGHOST" >> $logfile
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
            break
          fi

          if [ "$unboundovervpn" == "0" ] || [ "$unboundovervpn" == "1" ] || [ "$unboundovervpn" == "2" ] || [ "$unboundovervpn" == "3" ] || [ "$unboundovervpn" == "4" ] || [ "$unboundovervpn" == "5" ] || [ "$unboundovervpn" == "e" ]; then
            if [ "$unboundovervpn" == "0" ]; then

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
              break

            elif [ "$unboundovervpn" == "1" ] || [ "$unboundovervpn" == "2" ] || [ "$unboundovervpn" == "3" ] || [ "$unboundovervpn" == "4" ] || [ "$unboundovervpn" == "5" ]; then

              if [ "$unboundovervpn" == "$unboundclient" ]; then
                echo -e "${CClear}\n[Unbound over VPN$unboundovervpn Already Active]"; sleep 2; break
              fi

              if [ "$unboundovervpn" == "1" ] || [ "$unboundovervpn" == "2" ] || [ "$unboundovervpn" == "3" ] || [ "$unboundovervpn" == "4" ] || [ "$unboundovervpn" == "5" ] && [ $unboundclient -ge 1 ]; then
                echo ""
                echo -e "${CRed}When changing a VPN Client Slot (from Slot #$unboundclient to Slot #$unboundovervpn), please proceed to 'Disable'"
                echo -e "first (option 0), then choose a new VPN Slot."
                sleep 5; break
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
                curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/nat-start" -o "/jffs/scripts/nat-start" && chmod 755 "/jffs/scripts/nat-start"
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
                # backup - curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/openvpn-event" -o "/jffs/scripts/openvpn-event" && chmod 755 "/jffs/scripts/openvpn-event"
              fi

              # Download and create the unbound_DNS_via_OVPN.sh file - many thanks to @Martineau and @Swinson
              if [ ! -f /jffs/addons/unbound/unbound_DNS_via_OVPN.sh ]; then
                curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 2 --retry-all-errors "https://raw.githubusercontent.com/MartineauUK/Unbound-Asuswrt-Merlin/dev/unbound_DNS_via_OVPN.sh" -o "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh" && chmod 755 "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh"
                # backup - curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/unbound_DNS_via_OVPN.sh" -o "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh" && chmod 755 "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh"
              fi

              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Unbound-over-VPN was enabled for VPNMON-R3" >> $logfile
              echo -e "${CClear}"
              unboundclient=$unboundovervpn
              saveconfig
              echo "Please reboot your router now if this is your first time or re-enabled Unbound over VPN"
              read -rsp $'Press any key to continue...\n' -n1 key
              break

            elif [ "$unboundovervpn" == "e" ]; then
              echo -e "${CClear}\n[Exiting]"; sleep 2; break
            fi

          else
            echo -e "${CClear}\n[Exiting]"; sleep 2; break
          fi
        done
      ;;

      5)
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

      6)
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

      7)
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

      [Ee]) echo -e "${CClear}\n[Exiting]"; sleep 2; break ;;

      8)
        amtmevents
        source "$config"
      ;;

      9)
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

    esac
done
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
  if [ "$version" == "$DLversion" ]
    then
      echo -e "You are on the latest version! Would you like to download anyways? This will overwrite${CClear}"
      echo -e "your local copy with the current build.${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo -e "\nDownloading VPNMON-R3 ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 5 --retry-delay 2 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
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
        curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 2 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
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
  curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 2 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/version.txt" -o "/jffs/addons/vpnmon-r3.d/version.txt"

  if [ -f $dlverpath ]
    then
      # Read in its contents for the current version file
      DLversion=$(cat $dlverpath)

      # Compare the new version with the old version and log it
      if [ "$beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLversion" != "$version" ]; then
        DLversionPF=$(printf "%-8s" $DLversion)
        versionPF=$(printf "%-8s" $version)
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$versionPF -> v$DLversionPF                                                                     ${CClear}"
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
      if promptyn "(y/n): "; then
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
  echo -e "${InvGreen} ${CClear} Please indicate which VPN/WG slots you would like VPNMON-R3 to monitor.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to enable/disable monitoring for each slot:${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"

    if [ "$availableslots" = "1 2" ]
    then
      if [ "$VPN1" == "1" ]; then VPN1Disp="${CGreen}Y${CCyan}"; else VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN2" == "1" ]; then VPN2Disp="${CGreen}Y${CCyan}"; else VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp${CClear}"
      echo ""
      read -p "Please select? (1-2, e=Exit): " SelectSlot
        case $SelectSlot in
          1) if [ "$VPN1" == "0" ]; then VPN1=1; VPN1Disp="${CGreen}Y${CCyan}"; elif [ "$VPN1" == "1" ]; then VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi;;
          2) if [ "$VPN2" == "0" ]; then VPN2=1; VPN2Disp="${CGreen}Y${CCyan}"; elif [ "$VPN2" == "1" ]; then VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi;;
          [Ee])
             { echo 'VPN1='$VPN1
               echo 'VPN2='$VPN2
             } > /jffs/addons/vpnmon-r3.d/vr3clients.txt
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Client Slot Monitoring configuration saved" >> $logfile
             timer="$timerloop"
             break;;
        esac

    elif [ "$availableslots" = "1 2 3 4 5" ]
    then
      if [ "$VPN1" == "1" ]; then VPN1Disp="${CGreen}Y${CCyan}"; else VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN2" == "1" ]; then VPN2Disp="${CGreen}Y${CCyan}"; else VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN3" == "1" ]; then VPN3Disp="${CGreen}Y${CCyan}"; else VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN4" == "1" ]; then VPN4Disp="${CGreen}Y${CCyan}"; else VPN4=0; VPN4Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN5" == "1" ]; then VPN5Disp="${CGreen}Y${CCyan}"; else VPN5=0; VPN5Disp="${CRed}N${CCyan}"; fi
      if [ "$WG1" == "1" ]; then WG1Disp="${CGreen}Y${CCyan}"; else WG1=0; WG1Disp="${CRed}N${CCyan}"; fi
      if [ "$WG2" == "1" ]; then WG2Disp="${CGreen}Y${CCyan}"; else WG2=0; WG2Disp="${CRed}N${CCyan}"; fi
      if [ "$WG3" == "1" ]; then WG3Disp="${CGreen}Y${CCyan}"; else WG3=0; WG3Disp="${CRed}N${CCyan}"; fi
      if [ "$WG4" == "1" ]; then WG4Disp="${CGreen}Y${CCyan}"; else WG4=0; WG4Disp="${CRed}N${CCyan}"; fi
      if [ "$WG5" == "1" ]; then WG5Disp="${CGreen}Y${CCyan}"; else WG5=0; WG5Disp="${CRed}N${CCyan}"; fi
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3) -${CClear} $VPN3Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(4) -${CClear} $VPN4Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(5) -${CClear} $VPN5Disp${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG1${CClear} ${CGreen}(6) -${CClear} $WG1Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG2${CClear} ${CGreen}(7) -${CClear} $WG2Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG3${CClear} ${CGreen}(8) -${CClear} $WG3Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG4${CClear} ${CGreen}(9) -${CClear} $WG4Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG5${CClear} ${CGreen}(0) -${CClear} $WG5Disp${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo ""
      read -p "Please select? (1-0, e=Exit): " SelectSlot
        case $SelectSlot in
          1) if [ "$VPN1" == "0" ]; then VPN1=1; VPN1Disp="${CGreen}Y${CCyan}"; elif [ "$VPN1" == "1" ]; then VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi;;
          2) if [ "$VPN2" == "0" ]; then VPN2=1; VPN2Disp="${CGreen}Y${CCyan}"; elif [ "$VPN2" == "1" ]; then VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi;;
          3) if [ "$VPN3" == "0" ]; then VPN3=1; VPN3Disp="${CGreen}Y${CCyan}"; elif [ "$VPN3" == "1" ]; then VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi;;
          4) if [ "$VPN4" == "0" ]; then VPN4=1; VPN4Disp="${CGreen}Y${CCyan}"; elif [ "$VPN4" == "1" ]; then VPN4=0; VPN4Disp="${CRed}N${CCyan}"; fi;;
          5) if [ "$VPN5" == "0" ]; then VPN5=1; VPN5Disp="${CGreen}Y${CCyan}"; elif [ "$VPN5" == "1" ]; then VPN5=0; VPN5Disp="${CRed}N${CCyan}"; fi;;
          6) if [ "$WG1" == "0" ]; then WG1=1; WG1Disp="${CGreen}Y${CCyan}"; elif [ "$WG1" == "1" ]; then WG1=0; WG1Disp="${CRed}N${CCyan}"; fi;;
          7) if [ "$WG2" == "0" ]; then WG2=1; WG2Disp="${CGreen}Y${CCyan}"; elif [ "$WG2" == "1" ]; then WG2=0; WG2Disp="${CRed}N${CCyan}"; fi;;
          8) if [ "$WG3" == "0" ]; then WG3=1; WG3Disp="${CGreen}Y${CCyan}"; elif [ "$WG3" == "1" ]; then WG3=0; WG3Disp="${CRed}N${CCyan}"; fi;;
          9) if [ "$WG4" == "0" ]; then WG4=1; WG4Disp="${CGreen}Y${CCyan}"; elif [ "$WG4" == "1" ]; then WG4=0; WG4Disp="${CRed}N${CCyan}"; fi;;
          0) if [ "$WG5" == "0" ]; then WG5=1; WG5Disp="${CGreen}Y${CCyan}"; elif [ "$WG5" == "1" ]; then WG5=0; WG5Disp="${CRed}N${CCyan}"; fi;;
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
             echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN/WG Client Slot Monitoring configuration saved" >> $logfile
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
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to enable/disable email event notifications:${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"

  if [ "$amtmemailsuccess" == "1" ]; then amtmemailsuccessdisp="${CGreen}Y${CCyan}"; else amtmemailsuccess=0; amtmemailsuccessdisp="${CRed}N${CCyan}"; fi
  if [ "$amtmemailfailure" == "1" ]; then amtmemailfailuredisp="${CGreen}Y${CCyan}"; else amtmemailfailure=0; amtmemailfailuredisp="${CRed}N${CCyan}"; fi
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN Success Event Notifications${CClear} ${CGreen}(1) -${CClear} $amtmemailsuccessdisp${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN Failure Event Notifications${CClear} ${CGreen}(2) -${CClear} $amtmemailfailuredisp${CClear}"
  echo ""
  read -p "Please select? (1-2, e=Exit, t=Test Email): " SelectSlot
    case $SelectSlot in
      1) if [ "$amtmemailsuccess" == "0" ]; then amtmemailsuccess=1; amtmemailsuccessdisp="${CGreen}Y${CCyan}"; elif [ "$amtmemailsuccess" == "1" ]; then amtmemailsuccess=0; amtmemailsuccessdisp="${CRed}N${CCyan}"; fi;;
      2) if [ "$amtmemailfailure" == "0" ]; then amtmemailfailure=1; amtmemailfailuredisp="${CGreen}Y${CCyan}"; elif [ "$amtmemailfailure" == "1" ]; then amtmemailfailure=0; amtmemailfailuredisp="${CRed}N${CCyan}"; fi;;
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

  if [ "$availableslots" == "1 2" ]
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

  if [ "$availableslots" == "1 2 3 4 5" ]
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

if [ "$availableslots" == "1 2" ]
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
  echo -e "${InvGreen} ${CClear} WG INSTRUCTIONS: Enter a 5-field comma-delimited row of WG Connections${CClear}"
  echo -e "${InvGreen} ${CClear} Format: ConnectionName,EndpointIP,EndpointPort,PrivateKey,PublicKey${CClear}"
  echo -e "${InvGreen} ${CClear} Example: ${CGreen}City WG,143.32.55.23,34334,fasdkkfj44j38affkasdjfj=,221t949asas42dfj32323kf=${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} NANO INSTRUCTIONS: CTRL-O + Enter (save), CTRL-X (exit)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG1${CClear} ${CGreen}(1)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt ]; then
      wglist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG2${CClear} ${CGreen}(2)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt ]; then
      wglist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG3${CClear} ${CGreen}(3)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt ]; then
      wglist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}wg4${CClear} ${CGreen}(4)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt ]; then
      wglist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo -e "${InvGreen} ${CClear}"

  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}WG5${CClear} ${CGreen}(5)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt ]; then
      wglist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $wglist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi
  echo ""
  read -p "Please select? (1-5, e=Exit): " SelectSlot
  case $SelectSlot in
    1) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr1.txt;;
    2) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr2.txt;;
    3) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr3.txt;;
    4) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr4.txt;;
    5) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3wgsvr5.txt;;
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
  echo -e "${InvGreen} ${CClear} WG INSTRUCTIONS: Insert CURL statement that outputs a 5-field comma-separated list${CClear}"
  echo -e "${InvGreen} ${CClear} in this format: ConnectionName,EndpointIP,EndpointPort,PrivateKey,PublicKey${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(e1)${CClear} View/Edit | ${CGreen}(x1)${CClear} Execute | ${CGreen}(s1)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation1" ] || [ "$automation1" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation1unenc=$(echo "$automation1" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation1unenc"
    fi
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(e2)${CClear} View/Edit | ${CGreen}(x2)${CClear} Execute | ${CGreen}(s2)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation2" ] || [ "$automation2" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation2unenc=$(echo "$automation2" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation2unenc"
    fi
  echo -e "${InvGreen} ${CClear}"

  if [ "$availableslots" == "1 2" ]; then
    echo ""
    read -p "Please select? (e1-e2, x1-x2, s1-s2, e=Exit): " SelectSlot2
    case $SelectSlot2 in
      e1)
         echo ""
         if [ "$automation1" == "" ] || [ -z "$automation1" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation1" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation1new
         if [ "$automation1new" == "" ] || [ -z "$automation1new" ]; then
           automation1=""
           saveconfig
         elif [ "$automation1new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr1.txt "VPNMON-R3 VPN Slot 1 Import" >/dev/null 2>&1
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
         if [ "$automation2" == "" ] || [ -z "$automation2" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation2" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation2new
         if [ "$automation2new" == "" ] || [ -z "$automation2new" ]; then
           automation2=""
           saveconfig
         elif [ "$automation2new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr2.txt "VPNMON-R3 VPN Slot 2 Import" >/dev/null 2>&1
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

  if [ "$availableslots" == "1 2 3 4 5" ]; then
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(e3)${CClear} View/Edit | ${CGreen}(x3)${CClear} Execute | ${CGreen}(s3)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation3" ] || [ "$automation3" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation3unenc=$(echo "$automation3" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation3unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(e4)${CClear} View/Edit | ${CGreen}(x4)${CClear} Execute | ${CGreen}(s4)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation4" ] || [ "$automation4" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation4unenc=$(echo "$automation4" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation4unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(e5)${CClear} View/Edit | ${CGreen}(x5)${CClear} Execute | ${CGreen}(s5)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation5" ] || [ "$automation5" == "" ]; then
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
      if [ -z "$wgautomation1" ] || [ "$wgautomation1" == "" ]; then
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      else
        wgautomation1unenc=$(echo "$wgautomation1" | openssl enc -d -base64 -A)
        echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation1unenc"
      fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG2${CClear} ${CGreen}(e7)${CClear} View/Edit | ${CGreen}(x7)${CClear} Execute | ${CGreen}(s7)${CClear} Skynet WL Import${CClear}"
      if [ -z "$wgautomation2" ] || [ "$wgautomation2" == "" ]; then
        echo -e "${InvGreen} ${CClear} Contents: <blank>"
      else
        wgautomation2unenc=$(echo "$wgautomation2" | openssl enc -d -base64 -A)
        echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation2unenc"
      fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG3${CClear} ${CGreen}(e8)${CClear} View/Edit | ${CGreen}(x8)${CClear} Execute | ${CGreen}(s8)${CClear} Skynet WL Import${CClear}"
    if [ -z "$wgautomation3" ] || [ "$wgautomation3" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      wgautomation3unenc=$(echo "$wgautomation3" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation3unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG4${CClear} ${CGreen}(e9)${CClear} View/Edit | ${CGreen}(x9)${CClear} Execute | ${CGreen}(s9)${CClear} Skynet WL Import${CClear}"
    if [ -z "$wgautomation4" ] || [ "$wgautomation4" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      wgautomation4unenc=$(echo "$wgautomation4" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$wgautomation4unenc"
    fi
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} WG5${CClear} ${CGreen}(e0)${CClear} View/Edit | ${CGreen}(x0)${CClear} Execute | ${CGreen}(s0)${CClear} Skynet WL Import${CClear}"
    if [ -z "$wgautomation5" ] || [ "$wgautomation5" == "" ]; then
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
         if [ "$automation1" == "" ] || [ -z "$automation1" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation1" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation1new
         if [ "$automation1new" == "" ] || [ -z "$automation1new" ]; then
           automation1=""
           saveconfig
         elif [ "$automation1new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr1.txt "VPNMON-R3 VPN Slot 1 Import" >/dev/null 2>&1
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
         if [ "$automation2" == "" ] || [ -z "$automation2" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation2" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation2new
         if [ "$automation2new" == "" ] || [ -z "$automation2new" ]; then
           automation2=""
           saveconfig
         elif [ "$automation2new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr2.txt "VPNMON-R3 VPN Slot 2 Import" >/dev/null 2>&1
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
         if [ "$automation3" == "" ] || [ -z "$automation3" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation3" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation3new
         if [ "$automation3new" == "" ] || [ -z "$automation3new" ]; then
           automation3=""
           saveconfig
         elif [ "$automation3new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr3.txt "VPNMON-R3 VPN Slot 3 Import" >/dev/null 2>&1
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
         if [ "$automation4" == "" ] || [ -z "$automation4" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation4" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation4new
         if [ "$automation4new" == "" ] || [ -z "$automation4new" ]; then
           automation4=""
           saveconfig
         elif [ "$automation4new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr4.txt "VPNMON-R3 VPN Slot 4 Import" >/dev/null 2>&1
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
         if [ "$automation5" == "" ] || [ -z "$automation5" ]; then
           echo -e "${CClear}Old Script: <blank>"
           echo ""
         else
           echo -en "${CClear}Old Script: "; echo "$automation5" | openssl enc -d -base64 -A
           echo ""
         fi
         read -rp 'Enter New Script (e=Exit): ' automation5new
         if [ "$automation5new" == "" ] || [ -z "$automation5new" ]; then
           automation5=""
           saveconfig
         elif [ "$automation5new" == "e" ]; then
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
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr5.txt "VPNMON-R3 VPN Slot 5 Import" >/dev/null 2>&1
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
       if [ "$wgautomation1" == "" ] || [ -z "$wgautomation1" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation1" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation1new
       if [ "$wgautomation1new" == "" ] || [ -z "$wgautomation1new" ]; then
         wgautomation1=""
         saveconfig
       elif [ "$wgautomation1new" == "e" ]; then
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
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 1 Import" >/dev/null 2>&1
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
       if [ "$wgautomation2" == "" ] || [ -z "$wgautomation2" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation2" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation2new
       if [ "$wgautomation2new" == "" ] || [ -z "$wgautomation2new" ]; then
         wgautomation2=""
         saveconfig
       elif [ "$wgautomation2new" == "e" ]; then
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
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 2 Import" >/dev/null 2>&1
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
       if [ "$wgautomation3" == "" ] || [ -z "$wgautomation3" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation3" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation3new
       if [ "$wgautomation3new" == "" ] || [ -z "$wgautomation3new" ]; then
         wgautomation3=""
         saveconfig
       elif [ "$wgautomation3new" == "e" ]; then
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
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 3 Import" >/dev/null 2>&1
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
       if [ "$wgautomation4" == "" ] || [ -z "$wgautomation4" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation4" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation4new
       if [ "$wgautomation4new" == "" ] || [ -z "$wgautomation4new" ]; then
         wgautomation4=""
         saveconfig
       elif [ "$wgautomation4new" == "e" ]; then
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
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 4 Import" >/dev/null 2>&1
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
       if [ "$wgautomation5" == "" ] || [ -z "$wgautomation5" ]; then
         echo -e "${CClear}Old Script: <blank>"
         echo ""
       else
         echo -en "${CClear}Old Script: "; echo "$wgautomation5" | openssl enc -d -base64 -A
         echo ""
       fi
       read -rp 'Enter New Script (e=Exit): ' wgautomation5new
       if [ "$wgautomation5new" == "" ] || [ -z "$wgautomation5new" ]; then
         wgautomation5=""
         saveconfig
       elif [ "$wgautomation5new" == "e" ]; then
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
       firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 WG Slot 5 Import" >/dev/null 2>&1
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
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Timer Loop Configuration                                                              ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate how long the timer cycle should take between VPN Connection checks.${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = 60 seconds)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$timerloop sec${CClear}"
  echo
  read -p "Please enter value in seconds [5-999] (e=Exit): " newTimerLoop
  if [ -z "$newTimerLoop" ] || echo "$newTimerLoop" | grep -qE "^(e|E)$"
  then
      if echo "$timerloop" | grep -qE "^([1-9][0-9]{0,2})$" && \
         [ "$timerloop" -ge 5 ] && [ "$timerloop" -le 999 ]
      then
          timer="$timerloop"
          printf "\n${CClear}[Exiting]\n"
          sleep 1 ; break
      else
          printf "\n${CRed}*ERROR*: Please enter a valid number between 5 and 999.${CClear}\n"
          sleep 3
      fi
  elif echo "$newTimerLoop" | grep -qE "^([1-9][0-9]{0,2})$" && \
       [ "$newTimerLoop" -ge 5 ] && [ "$newTimerLoop" -le 999 ]
  then
      timerloop="$newTimerLoop"
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Timer Loop Configuration saved" >> $logfile
      saveconfig
      timer="$timerloop"
      printf "\n${CClear}[OK]\n"
      sleep 1 ; break
  else
      printf "\n${CRed}*ERROR*: Please enter a valid number between 5 and 999.${CClear}\n"
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
      currlogsize="$(wc -l $logfile | awk '{ print $1 }')" # Determine the number of rows in the log

      if [ "$currlogsize" -gt "$logsize" ] # If it's bigger than the max allowed, tail/trim it!
      then
          echo "$(tail -$logsize $logfile)" > $logfile
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Trimmed the log file down to $logsize lines" >> $logfile
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# saveconfig saves the vpnmon-r3.cfg file after every major change, and applies that to the script on the fly

saveconfig()
{
   { echo 'availableslots="'"$availableslots"'"'
     echo 'PINGHOST="'"$PINGHOST"'"'
     echo 'logsize='$logsize
     echo 'timerloop='$timerloop
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
     echo 'monitorwan='$monitorwan
     echo 'updateskynet='$updateskynet
     echo 'amtmemailsuccess='$amtmemailsuccess
     echo 'amtmemailfailure='$amtmemailfailure
     echo 'rstspdmerlin='$rstspdmerlin
   } > "$config"

   echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: New vpnmon-r3.cfg File Saved" >> $logfile
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
  if [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "0" ]; then
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

  #Pick the scenario and send email
  if [ "$1" == "1" ] && [ "$amtmemailfailure" == "1" ]; then
    if [ "$2" == "Recovering from WAN Down" ]; then
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
    elif [ "$2" == "VPN Slot In Error State" ]; then
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
    elif [ "$2" == "VPN Tunnel Disconnected" ]; then
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
    elif [ "$2" == "VPN Slot Is Non-Responsive" ]; then
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
    elif [ "$2" == "VPN Slot Exceeded Max Ping" ]; then
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
    elif [ "$2" == "VPN Slot Not Synced With Unbound" ]; then
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
    ##-------------------------------------##
    ## Modified by Dan G. [2025-Jul-16]    ##
    ##-------------------------------------##
    elif [ "$2" == "VPN Server List Query Yielded 0 Rows" ]; then
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
    elif [ "$2" == "WG Server List Query Yielded 0 Rows" ]; then
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
    elif [ "$2" == "WG Slot Exceeded Max Ping" ]; then
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
    elif [ "$2" == "WG Handshake Exceeded" ]; then
      emailSubject="WARNING: WG Slot $3 Exceeded Handshake"
      emailBodyTitle="WARNING: WG Slot $3 Exceeded Handshake"
      {
      printf "<b>Date/Time:</b> $(date +'%b %d %Y %X')\n"
      printf "<b>Asus Router Model:</b> ${ROUTERMODEL}\n"
      printf "<b>Firmware/Build Number:</b> ${FWBUILD}\n"
      printf "\n"
      printf "<b>WARNING: VPNMON-R3</b> has detected that WG Slot $3 exceeded a 200s handshake. WG Slot $3 has been reset.\n"
      printf "Please check your network environment and configuration if this error continues to persist."
      printf "\n"
      } > "$tmpEMailBodyFile"
    elif [ "$2" == "WG Tunnel Disconnected" ]; then
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
    elif [ "$2" == "WG Slot Is Non-Responsive" ]; then
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

  if [ "$1" == "0" ] && [ "$amtmemailsuccess" == "1" ]; then
    if [ "$2" == "VPN Connection Scheduled Reset" ]; then
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
    elif [ "$2" == "VPN Reset" ]; then
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
    elif [ "$2" == "VPN Killed" ]; then
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
    elif [ "$2" == "WG Connection Scheduled Reset" ]; then
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
    elif [ "$2" == "WG Reset" ]; then
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
    elif [ "$2" == "WG Killed" ]; then
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
  currvpnstate="$(_VPN_GetClientState_ $1)"

  if [ "$currvpnstate" -ne 0 ]; then
    printf "${CGreen}\r[Stopping VPN Client $1]"
    service stop_vpnclient$1 >/dev/null 2>&1
    sleep 20
    if [ "$currvpnstate" == "-1" ]; then
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
      sleep 10
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting VPN$1 Settle]"
      sleep 10
    else
      #Pick a random server from the alternate servers file, populate in vpn client slot, and restart
      printf "\33[2K\r"
      printf "${CGreen}\r[Selecting Random Entry]"
      RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
      R_LINE=$(( RANDOM % servers + 1 ))
      RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/addons/vpnmon-r3.d/vr3svr$1.txt)
      nvram set vpn_client"$1"_addr="$RNDVPNIP"
      nvram set vpn_client"$1"_desc="VPN$1 - $RNDVPNIP added by VPNMON-R3"
      sleep 2
      #Restart the new server currently allocated to that vpn slot
      printf "\33[2K\r"
      printf "${CGreen}\r[Starting VPN Client $1]"
      service start_vpnclient$1 >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - New Server: $RNDVPNIP" >> $logfile
      resettimer $1 "VPN"
      sleep 10
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting VPN$1 Settle]"
      sleep 10
    fi
  else
    #Restart the same server currently allocated to that vpn slot
    printf "\33[2K\r"
    printf "${CGreen}\r[Starting VPN Client $1]"
    currvpnhost="$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)"
    service start_vpnclient$1 >/dev/null 2>&1
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - Current Server: $currvpnhost" >> $logfile
    resettimer $1 "VPN"
    sleep 10
    printf "\33[2K\r"
    printf "${CGreen}\r[Letting VPN$1 Settle]"
    sleep 10
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Initiate a VPN restart - $1 = slot number

restartwg()
{

  echo -e "${CGreen}\nMessages:                           ${CClear}"
  echo ""

  #Check the current connection state of vpn slot
  currwgstate="$(_WG_GetClientState_ $1)"

  if [ "$currwgstate" -ne 0 ]; then
    printf "${CGreen}\r[Stopping WG Client $1]"
    service "stop_wgc $1" >/dev/null 2>&1
    sleep 20
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
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WG$1 Connection Restarted - Current Server: $currwghostname | $currwghost" >> $logfile
      resettimer $1 "WG"
      sleep 10
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting WG$1 Settle]"
      sleep 10
    else
      #Pick a random server from the alternate servers file, populate in wg client slot, and restart
      printf "\33[2K\r"
      printf "${CGreen}\r[Selecting Random Entry]"
      RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
      R_LINE=$(( RANDOM % servers + 1 ))

      #---------WG-specific nvram values

      WGLINE=$(sed -n "${R_LINE}p" /jffs/addons/vpnmon-r3.d/vr3wgsvr$1.txt)
      wgdescription=$(echo "$WGLINE" | cut -d ',' -f 1)
      endpointip=$(echo "$WGLINE" | cut -d ',' -f 2)
      endpointport=$(echo "$WGLINE" | cut -d ',' -f 3)
      privatekey=$(echo "$WGLINE" | cut -d ',' -f 4)
      publickey=$(echo "$WGLINE" | cut -d ',' -f 5)
      nvram set wgc"$1"_desc="$wgdescription"
      nvram set wgc"$1"_ep_addr="$endpointip"
      nvram set wgc"$1"_ep_addr_r="$endpointip"
      nvram set wgc"$1"_ep_port="$endpointport"
      nvram set wgc"$1"_priv="${privatekey}"
      nvram set wgc"$1"_ppub="${publickey}"
      sleep 2

      #---------WG-specific nvram values

      #Restart the new server currently allocated to that wg slot
      printf "\33[2K\r"
      printf "${CGreen}\r[Starting WG Client $1]"
      service "start_wgc $1" >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WG$1 Connection Restarted - New Server: $wgdescription | $endpointip" >> $logfile
      resettimer $1 "WG"
      sleep 10
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting WG$1 Settle]"
      sleep 10
    fi
  else
    #Restart the same server currently allocated to that wg slot
    printf "\33[2K\r"
    printf "${CGreen}\r[Starting WG Client $1]"
    currwghost="$($timeoutcmd$timeoutsec nvram get wgc$1_ep_addr)"
    service "start_wgc $1" >/dev/null 2>&1
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WG$1 Connection Restarted - Current Server: $currwghost" >> $logfile
    resettimer $1 "WG"
    sleep 10
    printf "\33[2K\r"
    printf "${CGreen}\r[Letting WG$1 Settle]"
    sleep 10
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

  if [ "$rstspdmerlin" == "1" ]
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
  sleep 15
  printf "\33[2K\r"
  printf "${CGreen}\r[Unmonitoring VPN Client $1]"

  # Write the VPN client file back with the correct monitoring configuration
  sed -i "s/^VPN$1=.*/VPN$1=0/" "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
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
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WG$1 has been stopped and no longer being monitored" >> $logfile
  sleep 15
  printf "\33[2K\r"
  printf "${CGreen}\r[Unmonitoring WG Client $1]"

  # Write the VPN client file back with the correct monitoring configuration
  sed -i "s/^WG$1=.*/WG$1=0/" "/jffs/addons/vpnmon-r3.d/vr3clients.txt"
  sleep 5

  # Restart VPN Director Routing Services
  restartrouting

}

# -------------------------------------------------------------------------------------------------------------------------
# Whitelist Server Slot IP lists in Skynet - $1 = VPN Slot

skynetwhitelist()
{
  if [ "$updateskynet" == "1" ]
  then
    ##-------------------------------------##
    ## Modified by Dan G. [2025-Jul-15]    ##
    ##-------------------------------------##
    if [[ $1 == wg* ]]; then
      slotnum="${1#wg}"
      printf "${CGreen}\r[Whitelisting WG Server Slot $slotnum List in the Skynet Firewall]${CClear}\n"
      awk -F',' '{print $2}' /jffs/addons/vpnmon-r3.d/vr3wgsvr${slotnum}.txt > /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt
      firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svrtmp.txt "VPNMON-R3 - WG Server Slot $slotnum Whitelist" >/dev/null 2>&1
      rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: WG Server Slot $slotnum List has been whitelisted in Skynet" >> $logfile
    else
      printf "${CGreen}\r[Whitelisting VPN Server Slot $1 List in the Skynet Firewall]${CClear}\n"
      firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr$1.txt "VPNMON-R3 - VPN Server Slot $1 Whitelist" >/dev/null 2>&1
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

    if [ "$availableslots" == "1 2" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt

    elif [ "$availableslots" == "1 2 3 4 5" ]; then
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

  if [ "$2" == "VPN" ]; then
    sed -i "s/^VPNTIMER$1=.*/VPNTIMER$1=$(date +%s)/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  elif [ "$2" == "WG" ]; then
    sed -i "s/^WGTIMER$1=.*/WGTIMER$1=$(date +%s)/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  fi

  source /jffs/addons/vpnmon-r3.d/vr3timers.txt

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
      if [ "$((VPN$slot))" == "1" ]
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
      if [ "$((WG$slot))" == "1" ]
      then
        if [ "$refreshserverlists" -eq 1 ]
        then
          if [ -f "/jffs/addons/vpnmon-r3.d/vr3wgsvr$slot.txt" ]
          then
            echo -e "${CGreen}[Executing Custom Server List Script for WG Slot $slot]${CClear}"
            slottmp="wgautomation${slot}"
            eval slottmp="\$${slottmp}"
            if [ -z "$slottmp" ]
            then
              echo ""
              echo -e "${CGreen}[Custom VPN Client Server Query not found for WG Slot $slot]${CClear}"
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
                wgslot = "wg$slot"
                cp "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" "/jffs/addons/vpnmon-r3.d/vr3wgsvr$slot.txt" >/dev/null 2>&1
                rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
                echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: Custom VPN Client Server List Query Executed for WG Slot $slot ($dlcnt rows)" >> $logfile
                sleep 3
                echo ""
                skynetwhitelist $wgslot
                echo ""
              else
                rm -f "/jffs/addons/vpnmon-r3.d/vr3svrtmp.txt" >/dev/null 2>&1
                echo -e "${CGreen}[$dlcnt Rows Retrieved From Source - Preserving Original Server List]${CClear}"
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List Query for WG Slot $slot yielded 0 rows -- Query may be invalid or VPN API service may be down" >> $logfile
                sendmessage 1 "WG Server List Query Yielded 0 Rows" $slot
                sleep 3
                echo ""
              fi
            fi
          else
            echo ""
            echo -e "${CRed}[Custom VPN Client Server List File not found for WG Slot $slot]${CClear}"
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List File not found for WG Slot $slot" >> $logfile
            sleep 3
          fi
        fi
        restartwg $slot
        sendmessage 0 "WG Connection Scheduled Reset" $slot

      fi
  done

  restartrouting
  resetspdmerlin

  # Clean up lockfile
  rm -f $lockfile >/dev/null 2>&1

  echo -e "\n${CClear}"
  exit 0
}

# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Oct-18] ##
##----------------------------------------##
# Find the VPN city
getvpnip()
{
  ubsync=""
  TUN="tun1$1"

  icanhazvpnip="$($timeoutcmd$timeoutsec nvram get vpn_client$1_rip)"
  if [ -z "$icanhazvpnip" ] || [ "$icanhazvpnip" = "unknown" ]
  then
     # Grab the public IP of the VPN Connection #
     icanhazvpnip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$TUN" --request GET --url https://ipv4.icanhazip.com"
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
      ubsync="${CYellow}-?[UB]${CClear}"
    else
      # Huge thanks to @SomewhereOverTheRainbow for his expertise in troublshooting and coming up with this DNS Resolver methodology!
      DNSResolver="$({ unbound-control flush whoami.akamai.net >/dev/null 2>&1; } && dig whoami.akamai.net +short @"$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{split($4, ip_addr, ":");if(substr($4,11) !~ /.*953.*/)print ip_addr[1];if(substr($4,11) !~ /.*953.*/)exit}')" -p "$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{if(substr($4,11) !~ /.*953.*/)print substr($4,11);if(substr($4,11) !~ /.*953.*/)exit}')" 2>/dev/null)"

      if [ -z "$DNSResolver" ]
      then
        ubsync="${CRed}-X[UB]${CClear}"
      # rudimentary check to make sure value coming back is in the format of an IP address... Don't care if it's more than 255.
      elif expr "$DNSResolver" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null
      then
        # If the DNS resolver and public VPN IP address don't match in our Unbound scenario, reset!
        if [ "$DNSResolver" != "$icanhazvpnip" ]
        then
          ubsync="${CRed}-X[UB]${CClear}"
          ResolverTimer=1
          unboundreset=$1
        else
          ubsync="${CGreen}->[UB]${CClear}"
        fi
      else
        ubsync="${CYellow}-?[UB]${CClear}"
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
# Find the WG city
getwgip()
{
  TUN="wgc$1"

  # Added ping workaround for site2site scenarios based on suggestion from @ZebMcKayhan
  TUN_IP=$(nvram get "$TUN"_addr | cut -d '/' -f1)
  ip rule add from $TUN_IP lookup $TUN prio 10

  icanhazwgip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$TUN" --request GET --url https://ipv4.icanhazip.com"
  icanhazwgip="$(eval $icanhazwgip)"
  if [ -z "$icanhazwgip" ] || echo "$icanhazwgip" | grep -qoE 'Internet|traffic|Error|error' ; then icanhazwgip="0.0.0.0" ; fi

  # Added based on suggestion from @ZebMcKayhan
  ip rule del prio 10

  if [ -z "$icanhazwgip" ]
  then
      wgip="000.000.000.000"
      return
  else
      wgip="$(printf '%15s' "$icanhazwgip")"
  fi

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
      vpncity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
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
      vpncity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
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
      vpncity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
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
      vpncity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
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
      vpncity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
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
  TUN_IP=$(nvram get "$TUN"_addr | cut -d '/' -f1)
  ip rule add from $TUN_IP lookup $TUN prio 10

  if [ "$1" = "1" ]
  then
    lastwgip1="$icanhazwgip"
    if [ "$lastwgip1" != "$oldwgip1" ]
    then
      wgcity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
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
      wgcity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
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
      wgcity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
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
      wgcity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
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
      wgcity="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$icanhazwgip | jq --raw-output .city"
      wgcity="$(eval $wgcity)"
      if [ -z "$wgcity" ] || echo "$wgcity" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then wgcity="Undetermined" ; fi
      wgcitychange="${CGreen}- NEW ${CClear}"
      wgcity5="$wgcity"
    fi
    wgcity="$wgcity5"
    oldwgip5="$lastwgip5"
  fi

  # Added based on suggestion from @ZebMcKayhan
  ip rule del prio 10

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
  TRIES=3
  TUN="tun1$1"

  while [ "$CNT" -lt "$TRIES" ]; do # Loop through number of tries
    ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings
    RC=$?
    # Grab the public IP of the VPN Connection #
    ICANHAZIP="$(curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$TUN" --request GET --url https://ipv4.icanhazip.com)"
    IC=$?
    if [ "$RC" -eq 0 ] && [ "$IC" -eq 0 ]; then  # If both ping/curl come back successful, then proceed
      vpnping=$(ping -I $TUN -c 1 -W 2 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
      VP=$?
      if [ "$VP" -eq 0 ]; then
        vpnhealth="${CGreen}[ OK ]${CClear}"
        vpnindicator="${InvGreen} ${CClear}"
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

      if [ "$CNT" -eq "$TRIES" ];then # But if it fails, report back that we have an issue requiring a VPN reset
        printf "\33[2K\r"
        vpnping=0
        vpnhealth="${CRed}[FAIL]${CClear}"
        vpnindicator="${InvRed} ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: VPN$1 failed to respond" >> $logfile
        if [ "$((VPN$1))" = "1" ]; then
          resetvpn=$1
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
  TRIES=3
  TUN="wgc$1"

  # Added ping workaround for site2site scenarios based on suggestion from @ZebMcKayhan
  TUN_IP=$(nvram get "$TUN"_addr | cut -d '/' -f1)
  ip rule add from $TUN_IP lookup $TUN prio 10

  while [ "$CNT" -lt "$TRIES" ]; do # Loop through number of tries
    ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings
    RC=$?
    # Grab the public IP of the VPN Connection #
    ICANHAZIP="$(curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$TUN" --request GET --url https://ipv4.icanhazip.com)"
    IC=$?
    if [ "$RC" -eq 0 ] && [ "$IC" -eq 0 ]; then  # If both ping/curl come back successful, then proceed
      wgping=$(ping -I $TUN -c 1 -W 2 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
      VP=$?
      if [ "$VP" -eq 0 ]; then
        wghealth="${CGreen}[ OK ]${CClear}"
        wgindicator="${InvGreen} ${CClear}"
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
      printf "\r${InvDkGray} ${CWhite} WG$1${CClear} [Attempt $CNT]"
      sleep 1 # Giving the VPN a chance to recover a certain number of times

      if [ "$CNT" -eq "$TRIES" ];then # But if it fails, report back that we have an issue requiring a VPN reset
        printf "\33[2K\r"
        wgping=0
        wghealth="${CRed}[FAIL]${CClear}"
        wgindicator="${InvRed} ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WG$1 failed to respond" >> $logfile
        if [ "$((WG$1))" = "1" ]; then
          resetwg=$1
        fi
      fi
    fi
  done

  # Added based on suggestion from @ZebMcKayhan
  ip rule del prio 10

}

# -------------------------------------------------------------------------------------------------------------------------

# Checkwan is a function that checks the viability of the current WAN connection and will loop until the WAN connection is restored.
checkwan()
{
  # Using Google's DNS server as default to test for WAN connectivity over verified SSL Handshake
  wandownbreakertrip=0
  testssl="$PING_HOST_Deflt"

  printf "\33[2K\r"
  printf "\r${InvYellow} ${CClear} [Checking WAN Connectivity]..."

  #Run main checkwan loop
  while true
  do
    # Check the actual WAN State from NVRAM before running connectivity test, or insert itself into loop after failing an SSL handshake test
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ] || [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
    then
        # Test the active WAN connection using 443 and verifying a handshake... if this fails, then the WAN connection is most likely down... or Google is down ;)
        if ($timeoutcmd$timeoutlng nc -w3 $testssl 443 >/dev/null 2>&1 && echo | $timeoutcmd$timeoutlng openssl s_client -connect $testssl:443 >/dev/null 2>&1 | awk 'handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 } $1 $2 == "SSLhandshake" { handshake = 1 }' >/dev/null 2>&1)
        ##OFF##if ($timeoutcmd$timeoutlng nc -w1 $testssl 443 >/dev/null 2>&1 && echo | $timeoutcmd$timeoutlng openssl s_client -connect $testssl:443 >/dev/null 2>&1 | awk '$1 == "SSL" && $2 == "handshake" { handshake = 1 } handshake && $1 == "Verification:" { ok = $2; exit } END { exit ok != "OK" }' >/dev/null 2>&1)
        then
            printf "\r${InvGreen} ${CClear} [Checking WAN Connectivity]...ACTIVE"
            sleep 1
            printf "\33[2K\r"
            return
        else
            wandownbreakertrip=1
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: WAN Connectivity Issue Detected" >> $logfile
        fi
    else
        wandownbreakertrip=1
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - ERROR: WAN Connectivity Issue Detected" >> $logfile
    fi

    if [ "$wandownbreakertrip" == "1" ]
    then
        # The WAN is most likely down, and keep looping through until NVRAM reports that it's back up
        while [ "$wandownbreakertrip" == "1" ]
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
              echo -e "${InvGreen} ${CClear} [Retrying to resume normal operations every 60 seconds]${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              spinner 60
              wandownbreakertrip=1
          else
              wandownbreakertrip=2
              break
          fi
        done
    fi

      # If the WAN was down, and now it has just reset, then run a VPN Reset, and try to establish a new VPN connection
      if [ "$wandownbreakertrip" = "2" ]
      then
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING:  WAN Link Detected -- Trying to reconnect/Reset VPN" >> $logfile
          wandownbreakertrip=0
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 is currently recovering from a WAN Down Situation                           ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Router has detected a WAN Link/Modem and waiting 300 seconds for general network${CClear}"
          echo -e "${InvGreen} ${CClear} connectivity to stabilize before re-establishing VPN connectivity.${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} [Retrying to resume normal operations in 300 seconds...Please stand by!]${CClear}"
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          spinner 300
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
           WAN0IP="$(curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WAN0IFNAME" --request GET --url https://ipv4.icanhazip.com)"
           WAN0CITY="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$WAN0IP | jq --raw-output .city"
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

        if [ "$WAN0PING" = "[FAILOVER]" ]
        then
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN0${CClear} | ${CGreen}[X]${CClear} | "
           printf "%-6s" "$WAN0IFNAME"
           echo -e " | ${CGreen}[ OK ]${CClear} | Failover     | $WAN0IP | $WAN0PING | $WAN0CITY"
        else
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN0${CClear} | ${CGreen}[X]${CClear} | "
           printf "%-6s" "$WAN0IFNAME"
           echo -e " | ${CGreen}[ OK ]${CClear} | Active       | $WAN0IP | $WAN0PING | $WAN0CITY"
        fi
     else
        echo -e "${InvDkGray}${CWhite}  WAN0${CClear} | ${CGreen}[X]${CClear} | ${CDkGray}[n/a]${CClear}  | ${CDkGray}[n/a ]${CClear} | Inactive     |           ${CDkGray}[n/a]${CClear} |      ${CDkGray}[n/a]${CClear} | ${CDkGray}[n/a]${CClear}"
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
           WAN1IP="$(curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WAN1IFNAME" --request GET --url https://ipv4.icanhazip.com)"
           WAN1CITY="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --request GET --url http://ip-api.com/json/$WAN1IP | jq --raw-output .city"
           WAN1CITY="$(eval $WAN1CITY)"
           if [ -z "$WAN1CITY" ] || echo "$WAN1CITY" | grep -qoE '\b(error.*:.*True.*|Undefined)\b' ; then WAN1CITY="$WAN1IP" ; fi
           WAN1IP="$(printf '%15s' "$WAN1IP")"
        fi

        if [ "$WAN1PING" = "[FAILOVER]" ]
        then
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN1${CClear} | ${CGreen}[X]${CClear} | "
           printf "%-6s" "$WAN1IFNAME"
           echo -e " | ${CGreen}[ OK ]${CClear} | Failover     | $WAN1IP | $WAN1PING | $WAN1CITY"
        else
           echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN1${CClear} | ${CGreen}[X]${CClear} | "
           printf "%-6s" "$WAN1IFNAME"
           echo -e " | ${CGreen}[ OK ]${CClear} | Active       | $WAN1IP | $WAN1PING | $WAN1CITY"
        fi
     else
        echo -e "${InvDkGray}${CWhite}  WAN1${CClear} | ${CGreen}[X]${CClear} | ${CDkGray}[n/a]${CClear}  | ${CDkGray}[n/a ]${CClear} | Inactive     |           ${CDkGray}[n/a]${CClear} |      ${CDkGray}[n/a]${CClear} | ${CDkGray}[n/a]${CClear}"
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

    if [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "0" ]; then
       amtmdisp="${CDkGray}Disabled        "
    elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "0" ]; then
       amtmdisp="${CGreen}Success         "
    elif [ "$amtmemailsuccess" == "0" ] && [ "$amtmemailfailure" == "1" ]; then
       amtmdisp="${CGreen}Failure         "
    elif [ "$amtmemailsuccess" == "1" ] && [ "$amtmemailfailure" == "1" ]; then
       amtmdisp="${CGreen}Success, Failure"
    else
       amtmdisp="${CDkGray}Disabled        "
    fi

    #display operations menu
    if [ "$availableslots" = "1 2" ]
    then
      echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                              ${CClear}"
      echo -e "${InvGreen} ${CClear} Reset/Reconnect VPN 1:${CGreen}(1)${CClear} 2:${CGreen}(2)${CClear}                      ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu${CClear}"
      echo -e "${InvGreen} ${CClear} Stop/Unmonitor  VPN 1:${CGreen}(!)${CClear} 2:${CGreen}(@)${CClear}                      ${InvGreen} ${CClear} ${CGreen}(R)${CClear}eset VPN CRON Time Scheduler: $schedtime"
      echo -e "${InvGreen} ${CClear} Enable/Disable ${CGreen}(M)${CClear}onitored VPN Slots                 ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): $logSizeStr"
      echo -e "${InvGreen} ${CClear} Update/Maintain ${CGreen}(V)${CClear}PN Server Lists                   ${InvGreen} ${CClear} ${CGreen}(A)${CClear}utostart VPNMON-R3 on Reboot: $rebootprot"
      echo -e "${InvGreen} ${CClear} Edit/R${CGreen}(U)${CClear}n Server List Automation                    ${InvGreen} ${CClear} ${CGreen}(T)${CClear}imer VPN Check Loop Interval: $timerLoopStr"
      echo -e "${InvGreen} ${CClear} AMTM Email Not${CGreen}(I)${CClear}fications: $amtmdisp         ${InvGreen} ${CClear} ${CGreen}(P)${CClear}ing Maximum Before Reset in ms: $pingResetStr"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""
    elif [ "$availableslots" = "1 2 3 4 5" ]
    then
      echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                              ${CClear}"
      echo -e "${InvGreen} ${CClear} Reset/Reconnect VPN 1:${CGreen}(1)${CClear} 2:${CGreen}(2)${CClear} 3:${CGreen}(3)${CClear} 4:${CGreen}(4)${CClear} 5:${CGreen}(5)${CClear}    ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu${CClear}"
      echo -e "${InvGreen} ${CClear} Stop/Unmonitor  VPN 1:${CGreen}(!)${CClear} 2:${CGreen}(@)${CClear} 3:${CGreen}(#)${CClear} 4:${CGreen}($)${CClear} 5:${CGreen}(%)${CClear}    ${InvGreen} ${CClear} ${CGreen}(R)${CClear}eset VPN CRON Time Scheduler: $schedtime"
      echo -e "${InvGreen} ${CClear} Reset/Reconnect  WG 1:${CGreen}(6)${CClear} 2:${CGreen}(7)${CClear} 3:${CGreen}(8)${CClear} 4:${CGreen}(9)${CClear} 5:${CGreen}(0)${CClear}    ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): $logSizeStr"
      echo -e "${InvGreen} ${CClear} Stop/Unmonitor   WG 1:${CGreen}(^)${CClear} 2:${CGreen}(&)${CClear} 3:${CGreen}(-)${CClear} 4:${CGreen}(+)${CClear} 5:${CGreen}(=)${CClear}    ${InvGreen} ${CClear} ${CGreen}(A)${CClear}utostart VPNMON-R3 on Reboot: $rebootprot"
      echo -e "${InvGreen} ${CClear} Enable/Disable ${CGreen}(M)${CClear}onitored VPN/WG Slots              ${InvGreen} ${CClear} ${CGreen}(T)${CClear}imer VPN Check Loop Interval: $timerLoopStr"
      echo -e "${InvGreen} ${CClear} Update/Maintain ${CGreen}(V)${CClear}PN/${CGreen}(W)${CClear}G Server Lists              ${InvGreen} ${CClear} ${CGreen}(P)${CClear}ing Maximum Before Reset in ms: $pingResetStr"
      echo -e "${InvGreen} ${CClear} Edit/R${CGreen}(U)${CClear}n Server List Automation                    ${InvGreen} ${CClear} AMTM Email Not${CGreen}(I)${CClear}fications: $amtmdisp"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
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

# Check and see if any commandline option is being used
if [ $# -eq 0 ] || [ -z "$1" ]
then
    clear
    exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    exit 0
fi

# Check and see if an invalid commandline option is being used
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-setup" ] || [ "$1" == "-reset" ] || [ "$1" == "-bw" ] || [ "$1" == "-noswitch" ] || [ "$1" == "-screen" ] || [ "$1" == "-now" ]
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
if [ "$1" == "-h" ] || [ "$1" == "-help" ]
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
if [ "$1" == "-setup" ]
then
    logoNM
    vsetup
    exit 0
fi

# Check to see if the reset option is being called
if [ "$1" == "-reset" ]
then
    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - INFO: VPN Reset initiated through -RESET switch" >> $logfile
    vreset
fi

# Check to see if the screen option is being called and run operations normally using the screen utility
if [ "$1" == "-screen" ]
then
    screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
    sleep 1
    ScreenSess=$(screen -ls | grep "vpnmon-r3" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        if [ "$bypassscreentimer" == "1" ]; then
          screen -dmS "vpnmon-r3" $apppath -noswitch
          sleep 1
          screen -r vpnmon-r3
        else
          clear
          echo -e "${CClear}Executing ${CGreen}VPNMON-R3 v$version${CClear} using the SCREEN utility..."
          echo ""
          echo -e "${CClear}IMPORTANT:"
          echo -e "${CClear}In order to keep VPNMON-R3 running in the background,"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          screen -dmS "vpnmon-r3" $apppath -noswitch
          sleep 5
          screen -r vpnmon-r3
          exit 0
        fi
      else
        if [ "$bypassscreentimer" == "1" ]; then
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
    screen -dr $ScreenSess
    exit 0
fi

# Check to see if the noswitch option is being called
if [ "$1" = "-noswitch" ]
then
    clear #last switch before the main program starts
    firstrun=1

    # Clean up lockfile
    rm -f $lockfile >/dev/null 2>&1

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
  echo -e "               ${CGreen}(S)${CWhite}how/${CGreen}(H)${CWhite}ide Operations Menu ${InvDkGray}        $tzspaces$(date) ${CClear}"

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
    echo -e "${CClear}  Port | Mon | IFace  | Health | WAN State    | Public WAN IP   | Ping-->WAN | City Exit"
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"

    #Cycle through the WANCheck connection function to display ping/city info
    wans=0
    for wans in 0 1
    do
        wancheck "$wans"
    done
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"
    echo ""
    echo -e "${InvDkGray} OpenVPN                                                                                                       ${CClear}"
    echo ""
  fi

  #Display VPN client slot grid
  if [ "$unboundclient" != "0" ]; then
     echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | City Exit / Time / UB"
  else
     echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | City Exit / Time"
  fi
  echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"

  if "$firstDataCollection" ; then printf "\r\033[0K${InvYellow} ${CClear} Please wait..." ; sleep 1 ; fi

  i=0
  for i in $availableslots #loop through the VPN slots
  do
      #Set variables
      citychange=""

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
      elif [ "$vpnstate" = "-1" ]
      then
         vpnstate="Error State "
         vpnhealth="${CDkGray}[n/a ]${CClear}"
         vpnindicator="${InvDkGray} ${CClear}"
         vpnip="${CDkGray}          [n/a]${CClear}"
         vpncity="${CDkGray}[n/a]${CClear}"
         svrping="     ${CDkGray}[n/a]${CClear}"
      elif [ "$vpnstate" = "1" ]
      then
         vpnstate="Connecting  "
         vpnhealth="${CDkGray}[n/a ]${CClear}"
         vpnindicator="${InvYellow} ${CClear}"
         vpnip="          ${CDkGray}[n/a]${CClear}"
         vpncity="${CDkGray}[n/a]${CClear}"
         svrping="     ${CDkGray}[n/a]${CClear}"
      elif [ "$vpnstate" = "2" ]
      then
         vpnstate="Connected   "
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
      if [ $((VPNTIMER$i)) == "0" ] || [ "$((VPN$i))" == "0" ]
      then
        sincelastreset=""
      else
        currtime=$(date +%s)
        timediff=$((currtime-VPNTIMER$i))
        sincelastreset=$(printf ': %dd %02dh:%02dm\n' $(($timediff/86400)) $(($timediff%86400/3600)) $(($timediff%3600/60)))
      fi

      if "$firstDataCollection" ; then printf "\r\033[0K" ; firstDataCollection=false ; fi

      # Print the results of all data gathered sofar #
      echo -e "$vpnindicator${InvDkGray}${CWhite} VPN$i${CClear} | $monitored | $servercnt | $vpnhealth | $vpnstate | $vpnip | $svrping | $vpncity$sincelastreset $citychange$ubsync"

      #if a vpn is monitored and disconnected, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$vpnstate" == "Disconnected" ]
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
        sendmessage 1 "VPN Tunnel Disconnected" $i
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

      #if a vpn is monitored and in error state, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$vpnstate" == "Error State " ]
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
        sendmessage 1 "VPN Slot In Error State" $i
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

      #if a vpn is monitored and not responsive, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$resetvpn" != "0" ]
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
        sendmessage 1 "VPN Slot Is Non-Responsive" $resetvpn
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

      # if a vpn connection ping is greater than a certain amount, restart it
      maxsvrping=$(awk "BEGIN {printf \"%3.0f\", ${vpnping}}") >/dev/null 2>&1
      MP=$?
      if [ $MP -ne 0 ]; then
        maxsvrping=0
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: Invalid VPN PING information received." >> $logfile
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

  echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"
  echo ""


#-----------------

  echo -e "${InvDkGray} Wireguard                                                                                                     ${CClear}"
  echo ""

  #Display WG client slot grid
  echo -e "  Slot | Mon |  Svrs  | Health | WG State     | Public WG IP    | Ping--->WG | City Exit / Time"
  echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"

  i=0
  for i in $availableslots #loop through the VPN slots
  do
      #Set variables
      wgcitychange=""

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
      elif [ "$wgstate" = "2" ]
      then
         wgstate="Connected   "
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
      if [ $((WGTIMER$i)) == "0" ] || [ "$((WG$i))" == "0" ]
      then
        wgsincelastreset=""
      else
        wgcurrtime=$(date +%s)
        wgtimediff=$((wgcurrtime-WGTIMER$i))
        wgsincelastreset=$(printf ': %dd %02dh:%02dm\n' $(($wgtimediff/86400)) $(($wgtimediff%86400/3600)) $(($wgtimediff%3600/60)))
      fi

      #if "$firstDataCollection" ; then printf "\r\033[0K" ; firstDataCollection=false ; fi

      # Print the results of all data gathered sofar #
      echo -e "$wgindicator${InvDkGray}${CWhite}  WG$i${CClear} | $wgmonitored | $wgservercnt | $wghealth | $wgstate | $wgip | $wgsvrping | $wgcity$wgsincelastreset $wgcitychange"

      #if a wg connection is monitored and disconnected, try to restart it
      if [ "$((WG$i))" == "1" ] && [ "$wgstate" == "Disconnected" ]
      then #reconnect
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WG$i has disconnected" >> $logfile
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
        sendmessage 1 "WG Tunnel Disconnected" $i
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

      #if the wg handshake exceeds 200s, try to restart it
      # Inspiration from ZebMcKayHan's WGC Watchdog Script
      if [ "$((WG$i))" == "1" ] && [ "$wgstate" == "Connected" ]
      then
        last_handshake=$(wg show wgc$i latest-handshakes | awk '{print $2}') >/dev/null 2>&1
        if [ ! -z $last_handshake ]
          then
            idle_seconds=$((`date +%s`-${last_handshake}))
            if [ "$idle_seconds" -gt "200" ]
            then #reconnect
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WG$i handshake exceeded 200s" >> $logfile
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
              sendmessage 1 "WG Handshake Exceeded" $i
              restartrouting
              resetspdmerlin
              exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
            fi
        fi
      fi

      # if a wg connection ping is greater than a certain amount, restart it
      maxsvrping=$(awk "BEGIN {printf \"%3.0f\", ${wgping}}") >/dev/null 2>&1
      MP=$?
      if [ $MP -ne 0 ]; then
        maxsvrping=0
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: Invalid WG PING information received." >> $logfile
      fi

      if [ "$pingreset" -gt 0 ]
      then
        if [ "$maxsvrping" -ge "$pingreset" ]
        then
          echo ""
          printf "\33[2K\r"
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WG$i PING exceeds max allowed ($pingreset ms)" >> $logfile
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
          sendmessage 1 "WG Slot Exceeded Max Ping" $i
          restartrouting
          resetspdmerlin
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        fi
      fi

      #if a wg is monitored and not responsive, try to restart it
      if [ "$((WG$i))" == "1" ] && [ "$resetwg" != "0" ]
      then #reconnect
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) VPNMON-R3[$$] - WARNING: WG$i is non-responsive and being reconnected" >> $logfile
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
        sendmessage 1 "WG Slot Is Non-Responsive" $resetwg
        restartrouting
        resetspdmerlin
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

      #Reset variables
      wgsincelastreset=""

  done

  echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"
  echo ""

#-----------------

  #display a standard timer#
  timer=0
  lastTimerSec=0
  updateTimer=true

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

  #Check to see if a reset is currently underway
  lockcheck
  prevHideOpts=X

  #if Unbound is active and out of sync, try to restart it
  if [ "$unboundclient" != "0" ] && [ "$ResolverTimer" = "1" ]
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
    sendmessage 1 "VPN Slot Not Synced With Unbound" $unboundreset
    restartrouting
    resetspdmerlin
    exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
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
