#!/bin/sh

# VPNMON-R3 v1.11 (VPNMON-R3.SH) is an all-in-one script that is optimized to maintain multiple VPN connections and is
# able to provide for the capabilities to randomly reconnect using a specified server list containing the servers of your
# choice. Special care has been taken to ensure that only the VPN connections you want to have monitored are tended to.
# This script will check the health of up to 5 VPN connections on a regular interval to see if monitored VPN conenctions
# are connected, and sends a ping to a host of your choice through each active connection. If it finds that a connection
# has been lost, it will execute a series of commands that will kill that single VPN client, and randomly picks one of
# your specified servers to reconnect to for each VPN client.

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

#Static Variables - please do not change
version="1.11"                                                  # Version tracker
beta=0                                                          # Beta switch
screenshotmode=0                                                # Switch to present bogus info for screenshots
apppath="/jffs/scripts/vpnmon-r3.sh"                            # Static path to the app
logfile="/jffs/addons/vpnmon-r3.d/vpnmon-r3.log"                # Static path to the log
dlverpath="/jffs/addons/vpnmon-r3.d/version.txt"                # Static path to the version file
config="/jffs/addons/vpnmon-r3.d/vpnmon-r3.cfg"                 # Static path to the config file
lockfile="/jffs/addons/vpnmon-r3.d/resetlock.txt"               # Static path to the reset lock file
availableslots="1 2 3 4 5"                                      # Available slots tracker
PINGHOST="8.8.8.8"                                              # Ping host
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

preparebar() 
{
  barlen=$1
  barspaces=$(printf "%*s" "$1")
  barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

progressbaroverride() 
{

  insertspc=" "
  bypasswancheck=0

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    if [ ! -z $7 ] && [ $1 -ge $7 ]; then
      barch=$(($7*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    else
      barch=$(($1*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    fi

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      printf "  ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%${CClear} [${CGreen}e${CClear}=Exit] [Selection? ${InvGreen} ${CClear}${CGreen}]\r${CClear}" "$barchars" "$barspaces"
    fi
  fi
  
  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ $key_press ]; then
      case $key_press in
          [1]) echo ""; restartvpn 1; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [2]) echo ""; restartvpn 2; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [3]) echo ""; restartvpn 3; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [4]) echo ""; restartvpn 4; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [5]) echo ""; restartvpn 5; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\!]) echo ""; killunmonvpn 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\@]) echo ""; killunmonvpn 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\#]) echo ""; killunmonvpn 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\$]) echo ""; killunmonvpn 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\%]) echo ""; killunmonvpn 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [Aa]) autostart;;
          [Cc]) vsetup;;
          [Ee]) echo -e "${CClear}\n"; exit 0;;
          [Hh]) resettimer=1; hideoptions=1;;
          [Ll]) vlogs;;
          [Mm]) vpnslots;;
          [Rr]) schedulevpnreset;;
          [Ss]) resettimer=1; hideoptions=0;;
          [Tt]) timerloopconfig;;
          [Uu]) vpnserverlistautomation;;
          [Vv]) vpnserverlistmaint;;
          [Xx]) uninstallr2;;
          *) timer=$timerloop;;
      esac
      bypasswancheck=1
  fi
}

progressbarpause() 
{

  insertspc=" "
  bypasswancheck=0

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    if [ ! -z $7 ] && [ $1 -ge $7 ]; then
      barch=$(($7*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    else
      barch=$(($1*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    fi

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      printf "  ${CWhite}${InvDkGray}Continuing Reset in $AltNum/5...${CClear} [${CGreen}p${CClear}=Pause] [${CGreen}e${CClear}=Exit] [Selection? ${InvGreen} ${CClear}${CGreen}]\r${CClear}" "$barchars" "$barspaces"
    fi
  fi
  
  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ $key_press ]; then
      case $key_press in
          [Pp]) vpause;;
          [Ee]) echo -e "${CClear}\n"; exit 0;;
      esac
      bypasswancheck=1
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# This function optionally uninstalls VPNMON-R2 if still found present on local router

uninstallr2()
{

if [ -f /jffs/scripts/vpnmon-r2.sh ]; then
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
        if promptyn "(y/n): "; then
          echo -e "\n${CClear}Uninstalling VPNMON-R2 components...${CClear}"
      
          if [ $(cat /jffs/addons/vpnmon-r2.d/vpnmon-r2.cfg | grep "UpdateUnbound" | cut -d '=' -f 2-) == "1" ]; then
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
          rm -r /jffs/addons/vpnmon-r2.d
          rm /jffs/scripts/vpnmon-r2.sh
          if [ -f /jffs/scripts/post-mount ]; then
            sed -i -e '/vpnmon-r2.sh/d' /jffs/scripts/post-mount >/dev/null 2>&1
          fi
          echo -e "\n${CClear}VPNMON-R2 has been uninstalled...${CClear}"
          echo ""
          read -rsp $'Press any key to continue...\n' -n1 key
          timer=$timerloop
          echo -e "${CClear}\n"
          return
        else
          timer=$timerloop
          echo -e "${CClear}\n"
          return
        fi
        
      ;;
      
      [Rr]) exec sh /jffs/scripts/vpnmon-r2.sh -setup; exit 0;;
      [Ee]) timer=$timerloop; echo -e "${CClear}\n"; return;;
    
    esac
fi

}

# -------------------------------------------------------------------------------------------------------------------------
# This function presents an Operational Menu in a Pause state, usually during VPN slot errors which give you a 5 second
# opportunity to pause in order to make any particular changes that might help your situation

vpause()
{

while true; do

  clear
  displayopsmenu
  printf "${CClear}Please select? (${CGreen}n${CClear}=UNpause, ${CGreen}e${CClear}=Exit)"
  read -p ": " SelectSlot
    case $SelectSlot in
          [1]) echo ""; restartvpn 1; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [2]) echo ""; restartvpn 2; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [3]) echo ""; restartvpn 3; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [4]) echo ""; restartvpn 4; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [5]) echo ""; restartvpn 5; restartrouting; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\!]) echo ""; killunmonvpn 1; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\@]) echo ""; killunmonvpn 2; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\#]) echo ""; killunmonvpn 3; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\$]) echo ""; killunmonvpn 4; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [\%]) echo ""; killunmonvpn 5; exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          [Aa]) autostart;;
          [Cc]) vsetup;;
          [Ee]) echo -e "${CClear}\n"; exit 0;;
          [Ll]) vlogs;;
          [Mm]) vpnslots;;
          [Rr]) schedulevpnreset;;
          [Tt]) timerloopconfig;;
          [Uu]) vpnserverlistautomation;;
          [Vv]) vpnserverlistmaint;;
          [Nn]) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
          *) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
      esac
done
}

# -------------------------------------------------------------------------------------------------------------------------
# creates needed config files if they don't exist

createconfigs()
{
  # Create initial vr3clients.txt & vr3timers.txt file
  if [ ! -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]; then
    if [ "$availableslots" == "1 2 3" ]; then
      { echo 'VPN1=0'
        echo 'VPN2=0'
        echo 'VPN3=0'
      } > /jffs/addons/vpnmon-r3.d/vr3clients.txt
      
    elif [ "$availableslots" == "1 2 3 4 5" ]; then
      { echo 'VPN1=0'
        echo 'VPN2=0'
        echo 'VPN3=0'
        echo 'VPN4=0'
        echo 'VPN5=0'
      } > /jffs/addons/vpnmon-r3.d/vr3clients.txt
      
    fi
  fi
  
  if [ ! -f /jffs/addons/vpnmon-r3.d/vr3timers.txt ]; then
    if [ "$availableslots" == "1 2 3" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
        echo 'VPNTIMER3=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
      
    elif [ "$availableslots" == "1 2 3 4 5" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
        echo 'VPNTIMER3=0'
        echo 'VPNTIMER4=0'
        echo 'VPNTIMER5=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
      
    fi
  fi
  
}

# -------------------------------------------------------------------------------------------------------------------------
# vsetup provide a menu interface to allow for initial component installs, uninstall, etc.

vsetup()
{

while true; do

  clear # Initial Setup
  if [ ! -f $config ]; then # Write /jffs/addons/vpnmon-r3.d/vpnmon-r3.cfg
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
        if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/jq" ]; then
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
          [ -z "$($timeoutcmd$timeoutsec nvram get odmpid)" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)" || RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)" # Thanks @thelonelycoder for this logic
          echo -e "Your router model is: ${CGreen}$RouterModel${CClear}"
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
        [ -z "$($timeoutcmd$timeoutsec nvram get odmpid)" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)" || RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)" # Thanks @thelonelycoder for this logic
        echo -e "Your router model is: ${CGreen}$RouterModel${CClear}"
        echo ""
        echo -e "Force Re-install?"
        if promptyn " (y/n): "
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
      [Ee]) #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
            echo ""
            timer=$timerloop
            break;;
    esac
done

}

# -------------------------------------------------------------------------------------------------------------------------
# vconfig is a function that provides a UI to choose various options for vpnmon-r3

vconfig() 
{

# Grab the VPNMON-R3 config file and read it in
if [ -f $config ]; then
  source $config
else
  clear
  echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
  echo ""
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
  echo -e "${CClear}"
  exit 0
fi
  
while true; do

  if [ $unboundclient -eq 0 ]; then 
    unboundclientexp="Disabled"
  else
    unboundclientexp="Enabled, VPN$unboundclient"
  fi
  
  if [ $refreshserverlists -eq 0 ]; then 
    refreshserverlistsdisp="Disabled"
  else
    refreshserverlistsdisp="Enabled"
  fi
  
  if [ $monitorwan -eq 0 ]; then
    monitorwandisp="Disabled"
  else
    monitorwandisp="Enabled"
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
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-6, e=Exit): " SelectSlot
    case $SelectSlot in
      1)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Number of VPN Client Slots Available on Router                                        ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate how many VPN client slots your router is configured with. Certain${CClear}"
        echo -e "${InvGreen} ${CClear} older model routers can only handle a maximum of 3 client slots, while newer models${CClear}"
        echo -e "${InvGreen} ${CClear} can handle 5."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = 5 VPN client slots)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$availableslots${CClear}"
        echo ""
        read -p "Please enter value (3 or 5)? (e=Exit): " EnterAvailableSlots
          if [ "$EnterAvailableSlots" == "3" ]; then
            availableslots="1 2 3"
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            saveconfig
          elif [ "$EnterAvailableSlots" == "5" ]; then
            availableslots="1 2 3 4 5"
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            saveconfig
          elif [ "$EnterAvailableSlots" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          else availableslots="1 2 3 4 5"
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            saveconfig
          fi
      ;;

      2) 
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom PING Host (to determine VPN health)                                            ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate which host you want to PING in order to determine VPN Client health.${CClear}"
        echo -e "${InvGreen} ${CClear} By default, the script will ping 8.8.8.8 (Google DNS) as it's reliable, fairly${CClear}"
        echo -e "${InvGreen} ${CClear} standard, and typically available globally. You can change this depending on your"
        echo -e "${InvGreen} ${CClear} local access and connectivity situation."
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} (Default = 8.8.8.8)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$PINGHOST${CClear}"
        echo ""
        read -p "Please enter valid IP4 address? (e=Exit): " NEWPINGHOST
          if [ "$NEWPINGHOST" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          else PINGHOST=$NEWPINGHOST
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New custom PING host entered: $PINGHOST" >> $logfile
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
        echo ""
        echo -e "${CClear}Current: ${CGreen}$logsize${CClear}"
        echo ""
        read -p "Please enter Log Size (in rows)? (0-9999, e=Exit): " NEWLOGSIZE

          if [ "$NEWLOGSIZE" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          elif [ $NEWLOGSIZE -ge 0 ] && [ $NEWLOGSIZE -le 9999 ]; then
            logsize=$NEWLOGSIZE
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New custom Event Log Size entered (in rows): $logsize" >> $logfile
            saveconfig
          else
            logsize=2000
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New custom Event Log Size entered (in rows): $logsize" >> $logfile
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
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - WARNING: Unbound was not detected on this system." >> $logfile
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
                rm /jffs/addons/unbound/unbound_DNS_via_OVPN.sh
              fi

              echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Unbound-over-VPN was removed from VPNMON-R3" >> $logfile
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
                curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/nat-start" -o "/jffs/scripts/nat-start" && chmod 755 "/jffs/scripts/nat-start"
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
                # backup - curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/openvpn-event" -o "/jffs/scripts/openvpn-event" && chmod 755 "/jffs/scripts/openvpn-event"
              fi

              # Download and create the unbound_DNS_via_OVPN.sh file - many thanks to @Martineau and @Swinson
              if [ ! -f /jffs/addons/unbound/unbound_DNS_via_OVPN.sh ]; then
                curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors "https://raw.githubusercontent.com/MartineauUK/Unbound-Asuswrt-Merlin/dev/unbound_DNS_via_OVPN.sh" -o "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh" && chmod 755 "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh"
                # backup - curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R2/main/Unbound/unbound_DNS_via_OVPN.sh" -o "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh" && chmod 755 "/jffs/addons/unbound/unbound_DNS_via_OVPN.sh"
              fi

              echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Unbound-over-VPN was enabled for VPNMON-R3" >> $logfile
              echo -e "${CClear}"
              read -rsp $'Please reboot your router now if this is your first time or re-enabled Unbound over VPN...\n' -n1 key
              
              unboundclient=$unboundovervpn
              saveconfig
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
        echo ""
        echo -e "${CClear}Current: ${CGreen}$refreshserverlistsdisp${CClear}"
        echo ""
        read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newrefreshserverlist

          if [ "$newrefreshserverlist" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          elif [ $newrefreshserverlist -eq 0 ]; then
            refreshserverlists=0
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom Server Lists Disabled on -RESET Switch" >> $logfile
            saveconfig
          else
            refreshserverlists=1
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom Server Lists Enabled on -RESET Switch" >> $logfile
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
        echo ""
        echo -e "${CClear}Current: ${CGreen}$monitorwandisp${CClear}"
        echo ""
        read -p "Please Choose? (Disable = 0, Enable = 1, e=Exit): " newmonitorwan

          if [ "$newmonitorwan" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          elif [ $newmonitorwan -eq 0 ]; then
            monitorwan=0
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: WAN Monitoring Disabled" >> $logfile
            saveconfig
          else
            monitorwan=1
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: WAN Monitoring Enabled" >> $logfile
            saveconfig          
          fi
      ;;

      [Ee]) echo -e "${CClear}\n[Exiting]"; sleep 2; break ;;

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
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Update Utility                                                                        ${CClear}"
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
      if promptyn "(y/n): "; then
        echo ""
        echo -e "\nDownloading VPNMON-R3 ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 5 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3-$DLversion.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Successfully downloaded and installed VPNMON-R3 v$DLversion" >> $logfile
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
      if promptyn " (y/n): "; then
        echo ""
        echo -e "\nDownloading VPNMON-R3 ${CGreen}v$DLversion${CClear}"
        curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3-$DLversion.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Successfully downloaded and installed VPNMON-R3 v$DLversion" >> $logfile
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
  curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/version.txt" -o "/jffs/addons/vpnmon-r3.d/version.txt"

  if [ -f $dlverpath ]
    then
      # Read in its contents for the current version file
      DLversion=$(cat $dlverpath)

      # Compare the new version with the old version and log it
      if [ "$beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLversion" != "$version" ]; then
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$version -> v$DLversion                                                                             ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: A new update (v$DLversion) is available to download" >> $logfile
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
        #
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
#exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
timer=$timerloop

}

# -------------------------------------------------------------------------------------------------------------------------
# vpnslots lets you pick which vpn slot numbers are being monitored by vpnmon-r3

vpnslots()
{

while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Client Slot Monitoring                                                            ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which VPN slots you would like VPNMON-R3 to monitor.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to enable/disable monitoring for each slot:${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    
    if [ "$availableslots" == "1 2 3" ]; then

      if [ "$VPN1" == "1" ]; then VPN1Disp="${CGreen}Y${CCyan}"; else VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN2" == "1" ]; then VPN2Disp="${CGreen}Y${CCyan}"; else VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN3" == "1" ]; then VPN3Disp="${CGreen}Y${CCyan}"; else VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3) -${CClear} $VPN3Disp${CClear}"
      echo ""
      read -p "Please select? (1-3, e=Exit): " SelectSlot
        case $SelectSlot in
          1) if [ "$VPN1" == "0" ]; then VPN1=1; VPN1Disp="${CGreen}Y${CCyan}"; elif [ "$VPN1" == "1" ]; then VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi;;
          2) if [ "$VPN2" == "0" ]; then VPN2=1; VPN2Disp="${CGreen}Y${CCyan}"; elif [ "$VPN2" == "1" ]; then VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi;;
          3) if [ "$VPN3" == "0" ]; then VPN3=1; VPN3Disp="${CGreen}Y${CCyan}"; elif [ "$VPN3" == "1" ]; then VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi;;
          [Ee]) 
             { echo 'VPN1='$VPN1
               echo 'VPN2='$VPN2
               echo 'VPN3='$VPN3
             } > /jffs/addons/vpnmon-r3.d/vr3clients.txt
             echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Client Slot Monitoring configuration saved" >> $logfile
             #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
             timer=$timerloop
             break;;
        esac    
    
    elif [ "$availableslots" == "1 2 3 4 5" ]; then
    
      if [ "$VPN1" == "1" ]; then VPN1Disp="${CGreen}Y${CCyan}"; else VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN2" == "1" ]; then VPN2Disp="${CGreen}Y${CCyan}"; else VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN3" == "1" ]; then VPN3Disp="${CGreen}Y${CCyan}"; else VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN4" == "1" ]; then VPN4Disp="${CGreen}Y${CCyan}"; else VPN4=0; VPN4Disp="${CRed}N${CCyan}"; fi
      if [ "$VPN5" == "1" ]; then VPN5Disp="${CGreen}Y${CCyan}"; else VPN5=0; VPN5Disp="${CRed}N${CCyan}"; fi
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3) -${CClear} $VPN3Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(4) -${CClear} $VPN4Disp${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(5) -${CClear} $VPN5Disp${CClear}"
      echo ""
      read -p "Please select? (1-5, e=Exit): " SelectSlot
        case $SelectSlot in
          1) if [ "$VPN1" == "0" ]; then VPN1=1; VPN1Disp="${CGreen}Y${CCyan}"; elif [ "$VPN1" == "1" ]; then VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi;;
          2) if [ "$VPN2" == "0" ]; then VPN2=1; VPN2Disp="${CGreen}Y${CCyan}"; elif [ "$VPN2" == "1" ]; then VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi;;
          3) if [ "$VPN3" == "0" ]; then VPN3=1; VPN3Disp="${CGreen}Y${CCyan}"; elif [ "$VPN3" == "1" ]; then VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi;;
          4) if [ "$VPN4" == "0" ]; then VPN4=1; VPN4Disp="${CGreen}Y${CCyan}"; elif [ "$VPN4" == "1" ]; then VPN4=0; VPN4Disp="${CRed}N${CCyan}"; fi;;
          5) if [ "$VPN5" == "0" ]; then VPN5=1; VPN5Disp="${CGreen}Y${CCyan}"; elif [ "$VPN5" == "1" ]; then VPN5=0; VPN5Disp="${CRed}N${CCyan}"; fi;;
          [Ee]) 
             { echo 'VPN1='$VPN1
               echo 'VPN2='$VPN2
               echo 'VPN3='$VPN3
               echo 'VPN4='$VPN4
               echo 'VPN5='$VPN5
             } > /jffs/addons/vpnmon-r3.d/vr3clients.txt
             echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Client Slot Monitoring configuration saved" >> $logfile
             #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
             timer=$timerloop
             break;;
      esac
    fi
done

}

# -------------------------------------------------------------------------------------------------------------------------
# vpnserverlistmaint lets you pick which vpn slot server list you want to edit/maintain

vpnserverlistmaint()
{
  
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Client Slot Server List Maintenance                                               ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which VPN Slot Server List you would like to edit/maintain.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to launch and edit the list with the NANO text editor${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} INSTRUCTIONS: Enter a single column of IP addresses or hostnames, as required by${CClear}"  
  echo -e "${InvGreen} ${CClear} your VPN provider. NANO INSTRUCTIONS: CTRL-O + Enter (save), CTRL-X (exit)${CClear}"  
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
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3)${CClear}"
    if [ -f /jffs/addons/vpnmon-r3.d/vr3svr3.txt ]; then
      iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr3.txt | sed 's/,$/\n/')
      echo -en "${InvGreen} ${CClear} Contents: "; printf "%.75s>\n" $iplist
    else
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    fi      
  echo -e "${InvGreen} ${CClear}"
  
  if [ "$availableslots" == "1 2 3" ]; then
    read -p "Please select? (1-3, e=Exit): " SelectSlot
    case $SelectSlot in
      1) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr1.txt;;
      2) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr2.txt;;
      3) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr3.txt;;
      [Ee]) #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch 
            timer=$timerloop
            break;;
    esac
  fi
  
  if [ "$availableslots" == "1 2 3 4 5" ]; then
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
      [Ee]) #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
            timer=$timerloop
            break;;
    esac
  fi

done

}

# -------------------------------------------------------------------------------------------------------------------------
# vpnserverlistautomation lets you pick which vpn slot server list automation you want to edit/execute

vpnserverlistautomation()
{
  
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Client Slot Server List Automation                                                ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate which VPN Slot Automation Script you would like to edit/execute.${CClear}"
  echo -e "${InvGreen} ${CClear} Custom VPN Slot Server Lists can also be whitelisted in Skynet using keys below.${CClear}"
  echo -e "${InvGreen} ${CClear} Use the corresponding ${CGreen}()${CClear} key to edit or launch your update statements${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} INSTRUCTIONS: Using carefully crafted CURL statements that query your VPN Provider's${CClear}"  
  echo -e "${InvGreen} ${CClear} server lists via API lookups, you can redirect their output into single-column IP${CClear}"
  echo -e "${InvGreen} ${CClear} address lists for use by VPNMON-R3 for each of your VPN Client Slots.${CClear}"  
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
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(e3)${CClear} View/Edit | ${CGreen}(x3)${CClear} Execute | ${CGreen}(s3)${CClear} Skynet WL Import${CClear}"
    if [ -z "$automation3" ] || [ "$automation3" == "" ]; then
      echo -e "${InvGreen} ${CClear} Contents: <blank>"
    else
      automation3unenc=$(echo "$automation3" | openssl enc -d -base64 -A)
      echo -en "${InvGreen} ${CClear} Contents: ${InvDkGray}${CWhite}"; printf "%.75s>\n" "$automation3unenc"
    fi
  echo -e "${InvGreen} ${CClear}"
  
  if [ "$availableslots" == "1 2 3" ]; then
    read -p "Please select? (e1-e3, x1-x3, s1-s3, e=Exit): " SelectSlot3
    case $SelectSlot3 in
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 1" >> $logfile
           saveconfig
         fi
      ;;
      
      x1)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation1unenc=$(echo "$automation1" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation1unenc"
         echo ""
         eval "$automation1unenc" > /jffs/addons/vpnmon-r3.d/vr3svr1.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr1.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr1.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 1 Server List]${CClear}"
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 1" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s1)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr1.txt "VPNMON-R3 VPN Slot 1 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 1 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 1" >> $logfile
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 2" >> $logfile
           saveconfig
         fi
      ;;

      x2)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation2unenc=$(echo "$automation2" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation2unenc"
         echo ""
         eval "$automation2unenc" > /jffs/addons/vpnmon-r3.d/vr3svr2.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr2.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr2.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 2 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 2" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s2)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr2.txt "VPNMON-R3 VPN Slot 2 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 2 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 2" >> $logfile
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 3" >> $logfile
           saveconfig
         fi      
      ;;

      x3)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation3unenc=$(echo "$automation3" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation3unenc"
         echo ""
         eval "$automation3unenc" > /jffs/addons/vpnmon-r3.d/vr3svr3.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr3.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr3.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 3 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 3" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s3)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr3.txt "VPNMON-R3 VPN Slot 3 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 3 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 3" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;
      
      [Ee]) #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
            timer=$timerloop
            break;;
    esac
  fi
  
  if [ "$availableslots" == "1 2 3 4 5" ]; then
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
    echo ""
    
    read -p "Please select? (e1-e5, x1-x5, s1-s5, e=Exit): " SelectSlot5
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 1" >> $logfile
           saveconfig
         fi
      ;;
      
      x1)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation1unenc=$(echo "$automation1" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation1unenc"
         echo ""
         eval "$automation1unenc" > /jffs/addons/vpnmon-r3.d/vr3svr1.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr1.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr1.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 1 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 1" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s1)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr1.txt "VPNMON-R3 VPN Slot 1 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 1 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 1" >> $logfile
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 2" >> $logfile
           saveconfig
         fi
      ;;

      x2)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation2unenc=$(echo "$automation2" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation2unenc"
         echo ""
         eval "$automation2unenc" > /jffs/addons/vpnmon-r3.d/vr3svr2.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr2.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr2.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 2 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 2" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s2)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr2.txt "VPNMON-R3 VPN Slot 2 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 2 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 2" >> $logfile
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 3" >> $logfile
           saveconfig
         fi      
      ;;

      x3)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation3unenc=$(echo "$automation3" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation3unenc"
         echo ""
         eval "$automation3unenc" > /jffs/addons/vpnmon-r3.d/vr3svr3.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr3.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr3.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 3 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 3" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;
        
      s3)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr3.txt "VPNMON-R3 VPN Slot 3 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 3 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 3" >> $logfile
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 4" >> $logfile
           saveconfig
         fi
      ;;

      x4)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation4unenc=$(echo "$automation4" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation4unenc"
         echo ""
         eval "$automation4unenc" > /jffs/addons/vpnmon-r3.d/vr3svr4.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr4.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr4.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 4 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 4" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s4)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr4.txt "VPNMON-R3 VPN Slot 4 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 4 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 4" >> $logfile
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
           echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Custom VPN Server List Command entered for VPN Slot 5" >> $logfile
           saveconfig
         fi
      ;;

      x5)
         echo ""
         echo -e "${CGreen}[Executing Script]${CClear}"
         automation5unenc=$(echo "$automation5" | openssl enc -d -base64 -A)
         echo -e "${CClear}Running: $automation5unenc"
         echo ""
         eval "$automation5unenc" > /jffs/addons/vpnmon-r3.d/vr3svr5.txt
         #Determine how many server entries are in each of the vpn slot alternate server files
         if [ -f /jffs/addons/vpnmon-r3.d/vr3svr5.txt ]; then
           dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr5.txt | wc -l) >/dev/null 2>&1 
           if [ $dlcnt -lt 1 ]; then 
             dlcnt=0
           elif [ -z $dlcnt ]; then 
             dlcnt=0
           fi
         else
           dlcnt=0
         fi
         echo ""
         echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
         echo ""
         echo -e "${CGreen}[Saved to VPN Client Slot 5 Server List]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Server List Command executed for VPN Slot 5" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;

      s5)
         echo ""
         echo -e "${CGreen}[Executing Skynet Whitelist Import]${CClear}"
         firewall import whitelist /jffs/addons/vpnmon-r3.d/vr3svr5.txt "VPNMON-R3 VPN Slot 5 Import" >/dev/null 2>&1
         echo ""
         echo -e "${CGreen}[Contents of VPN Slot 5 Imported]${CClear}"         
         echo ""
         echo -e "${CGreen}[Execution Complete]${CClear}"
         echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Skynet Whitelist imported for VPN Slot 5" >> $logfile
         echo ""
         read -rsp $'Press any key to acknowledge...\n' -n1 key
      ;;
      
      [Ee]) #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
            timer=$timerloop
            break;;
    esac
  fi

done

}

# -------------------------------------------------------------------------------------------------------------------------
# timerloopconfig lets you configure how long you want the timer cycle to last between vpn connection checks

timerloopconfig()
{
  
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Timer Loop Configuration                                                              ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate how long the timer cycle should take between VPN Connection checks.${CClear}"
  echo -e "${InvGreen} ${CClear} (Default = 60 seconds)${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Current: ${CGreen}$timerloop sec${CClear}"
  echo ""
  read -p "Please enter value (1-999)? (e=Exit): " EnterTimerLoop
  case $EnterTimerLoop in
    [1-9]) 
      timerloop=$EnterTimerLoop
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Timer Loop Configuration saved" >> $logfile
      saveconfig
      timer=$timerloop
    ;;
    
    [1-9][0-9])
      timerloop=$EnterTimerLoop
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Timer Loop Configuration saved" >> $logfile
      saveconfig
      timer=$timerloop    
    ;;
    
    [1-9][0-9][0-9])
      timerloop=$EnterTimerLoop
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Timer Loop Configuration saved" >> $logfile
      saveconfig
      timer=$timerloop    
    ;;
    
    *)
      echo ""
      echo -e "${CClear}[Exiting]"
      timer=$timerloop
      break    
    ;;
  esac

done

}

# -------------------------------------------------------------------------------------------------------------------------
# schedulevpnreset lets you enable and set a time for a scheduled daily vpn reset

schedulevpnreset()
{
  
while true; do
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Reset Scheduler                                                                   ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} Please indicate below if you would like to enable and schedule a daily VPN Reset CRON"
  echo -e "${InvGreen} ${CClear} job. This will reset each monitored VPN connection. (Default = Disabled)"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo -e "${InvGreen} ${CClear}"
  if [ "$schedule" == "0" ]; then
    echo -e "${InvGreen} ${CClear} Current: ${CRed}Disabled${CClear}"
  elif [ "$schedule" == "1" ]; then
    schedhrs=$(awk "BEGIN {printf \"%02.f\",${schedulehrs}}")
    schedmin=$(awk "BEGIN {printf \"%02.f\",${schedulemin}}")
    schedtime="${CGreen}$schedhrs:$schedmin${CClear}"
    echo -e "${InvGreen} ${CClear} Current: ${CGreen}Enabled, Daily @ $schedtime${CClear}"
  fi
  echo ""
  read -p 'Schedule Daily Reset? (0=No, 1=Yes, e=Exit): ' schedule1
  if [ "$schedule1" == "" ] || [ -z "$schedule1" ]; then schedule=0; else schedule="$schedule1"; fi # Using default value on enter keypress

  if [ "$schedule" == "0" ]; then

    if [ -f /jffs/scripts/services-start ]; then
      sed -i -e '/vpnmon-r3.sh/d' /jffs/scripts/services-start
      cru d RunVPNMONR3reset
      schedule=0
      schedulehrs=1
      schedulemin=0
      echo ""
      echo -e "${CGreen}[Modifiying SERVICES-START file]..."
      sleep 2
      echo ""
      echo -e "${CGreen}[Modifying CRON jobs]..."
      sleep 2
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Reset Schedule Disabled" >> $logfile
      saveconfig
      #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      timer=$timerloop
      break
    fi

  elif [ "$schedule" == "1" ]; then

    echo ""
    echo -e "${InvGreen} ${InvDkGray}${CWhite} VPN Reset Scheduler                                                                   ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} Please indicate below what time you would like to schedule a daily VPN Reset CRON"
    echo -e "${InvGreen} ${CClear} job. (Default = 1 hrs / 0 min = 01:00 or 1:00am)"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    read -p 'Schedule HOURS?: ' schedulehrs1
      if [ "$schedulehrs1" == "" ] || [ -z "$schedulehrs1" ]; then schedulehrs=1; else schedulehrs="$schedulehrs1"; fi # Using default value on enter keypress
    read -p 'Schedule MINUTES?: ' schedulemin1
      if [ "$schedulemin1" == "" ] || [ -z "$schedulemin1" ]; then schedulemin=0; else schedulemin="$schedulemin1"; fi # Using default value on enter keypress
    
    echo ""
    echo -e "${CGreen}[Modifying SERVICES-START file]..."
    sleep 2
    
    if [ -f /jffs/scripts/services-start ]; then

      if ! grep -q -F "sh /jffs/scripts/vpnmon-r3.sh -reset" /jffs/scripts/services-start; then
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
      
    echo ""
    echo -e "${CGreen}[Modifying CRON jobs]..."
    sleep 2
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Reset Schedule Enabled" >> $logfile
    saveconfig
    #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    timer=$timerloop
    break
    
  elif [ "$schedule" == "e" ]; then
    #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    timer=$timerloop
    break
  
  else

    schedule=0
    schedulehrs=1
    schedulemin=0
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
  if [ "$autostart" == "0" ]; then
    echo -e "${InvGreen} ${CClear} Current: ${CRed}Disabled${CClear}"
  elif [ "$autostart" == "1" ]; then
    echo -e "${InvGreen} ${CClear} Current: ${CGreen}Enabled${CClear}"
  fi
  echo ""
  read -p 'Enable Reboot Protection? (0=No, 1=Yes, e=Exit): ' autostart1
  
  if [ "$autostart1" == "" ] || [ -z "$autostart1" ]; then autostart=0; else autostart="$autostart1"; fi # Using default value on enter keypress

  if [ "$autostart" == "0" ]; then

    if [ -f /jffs/scripts/post-mount ]; then
      sed -i -e '/vpnmon-r3.sh/d' /jffs/scripts/post-mount
      autostart=0
      echo ""
      echo -e "${CGreen}[Modifying POST-MOUNT file]..."
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Reboot Protection Disabled" >> $logfile
      saveconfig
      sleep 2
      #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      timer=$timerloop
      break
    fi

  elif [ "$autostart" == "1" ]; then

    if [ -f /jffs/scripts/post-mount ]; then

      if ! grep -q -F "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" /jffs/scripts/post-mount; then
        echo "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" >> /jffs/scripts/post-mount
        autostart=1
        echo ""
        echo -e "${CGreen}[Modifying POST-MOUNT file]..."
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Reboot Protection Enabled" >> $logfile
        saveconfig
        sleep 2
        #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        timer=$timerloop
        break
      else
        autostart=1
        saveconfig
        sleep 1
      fi

    else
      echo "#!/bin/sh" > /jffs/scripts/post-mount
      echo "" >> /jffs/scripts/post-mount
      echo "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" >> /jffs/scripts/post-mount
      chmod 755 /jffs/scripts/post-mount
      autostart=1
      echo ""
      echo -e "${CGreen}[Modifying POST-MOUNT file]..."
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Reboot Protection Enabled" >> $logfile
      saveconfig
      sleep 2
      #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      timer=$timerloop
      break
    fi
  
  elif [ "$autostart" == "e" ]; then
  #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
  timer=$timerloop
  break
  
  else
    autostart=0
    saveconfig
  fi
  
done
}

# -------------------------------------------------------------------------------------------------------------------------
# trimlogs will cut down log size (in rows) based on custom value

trimlogs() 
{

  if [ $logsize -gt 0 ]; then

      currlogsize=$(wc -l $logfile | awk '{ print $1 }' ) # Determine the number of rows in the log

      if [ $currlogsize -gt $logsize ] # If it's bigger than the max allowed, tail/trim it!
        then
          echo "$(tail -$logsize $logfile)" > $logfile
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Trimmed the log file down to $logsize lines" >> $logfile
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
     echo 'automation1="'"$automation1"'"'
     echo 'automation2="'"$automation2"'"'
     echo 'automation3="'"$automation3"'"'
     echo 'automation4="'"$automation4"'"'
     echo 'automation5="'"$automation5"'"'
     echo 'refreshserverlists='$refreshserverlists
     echo 'unboundclient='$unboundclient
     echo 'monitorwan='$monitorwan
   } > $config
   
   echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: New vpnmon-r3.cfg File Saved" >> $logfile
   
   #exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
  
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
# Testing to see if VPNMON-R3 external reset is currently running, and if so, hold off until it finishes
lockcheck() 
{
 
  while [ -f "$lockfile" ]; do
    # clear screen
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
  
  if [ "$lockactive" == "1" ]; then
    resettimer=1
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
 
  if [ $currvpnstate -ne 0 ]; then
    printf "${CGreen}\r[Stopping VPN Client $1]"
    service stop_vpnclient$1 >/dev/null 2>&1
    sleep 20
    if [ "$currvpnstate" == "-1" ]; then
      nvram set vpn_client$1_state=0
    fi
    printf "\33[2K\r"
  fi
  
  #Determine how many server entries are in the assigned vpn slot alternate servers file
  if [ -f /jffs/addons/vpnmon-r3.d/vr3svr$1.txt ]; then
    servers=$(cat /jffs/addons/vpnmon-r3.d/vr3svr$1.txt | wc -l) >/dev/null 2>&1 
    if [ -z $servers ] || [ $servers -eq 0 ]; then
      #Restart the same server currently allocated to that vpn slot
      currvpnhost=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
      printf "\33[2K\r"
      printf "${CGreen}\r[Starting VPN Client $1]"
      service start_vpnclient$1 >/dev/null 2>&1
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - Current Server: $currvpnhost" >> $logfile
      resettimer $1
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
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - New Server: $RNDVPNIP" >> $logfile
      resettimer $1
      sleep 10
      printf "\33[2K\r"
      printf "${CGreen}\r[Letting VPN$1 Settle]"
      sleep 10
    fi
  else
    #Restart the same server currently allocated to that vpn slot
    printf "\33[2K\r"
    printf "${CGreen}\r[Starting VPN Client $1]"
    currvpnhost=$($timeoutcmd$timeoutsec nvram get vpn_client$1_addr)
    service start_vpnclient$1 >/dev/null 2>&1
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted - Current Server: $currvpnhost" >> $logfile
    resettimer $1
    sleep 10
    printf "\33[2K\r"
    printf "${CGreen}\r[Letting VPN$1 Settle]"
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
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Director Routing Service Restarted" >> $logfile
  sleep 5
  printf "\33[2K\r"
  trimlogs
  
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
  echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 has been stopped and no longer being monitored" >> $logfile
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
# Reset the  VPN connection timer

resettimer()
{

 # Create initial vr3timers.txt file if it does not exist
  if [ ! -f /jffs/addons/vpnmon-r3.d/vr3timers.txt ]; then
    
    if [ "$availableslots" == "1 2 3" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
        echo 'VPNTIMER3=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
      
    elif [ "$availableslots" == "1 2 3 4 5" ]; then
      { echo 'VPNTIMER1=0'
        echo 'VPNTIMER2=0'
        echo 'VPNTIMER3=0'
        echo 'VPNTIMER4=0'
        echo 'VPNTIMER5=0'
      } > /jffs/addons/vpnmon-r3.d/vr3timers.txt
      
    fi
  fi

  sed -i "s/^VPNTIMER$1=.*/VPNTIMER$1=$(date +%s)/" "/jffs/addons/vpnmon-r3.d/vr3timers.txt"
  
  source /jffs/addons/vpnmon-r3.d/vr3timers.txt

}

# -------------------------------------------------------------------------------------------------------------------------
# Reset the managed VPN connections

vreset()
{

  # Grab the VPNMON-R3 config file and read it in
  if [ -f $config ]; then
    source $config
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]; then
    source /jffs/addons/vpnmon-r3.d/vr3clients.txt
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Client Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
  # Create a rudimentary lockfile so that VPNMON-R2 doesn't interfere during the reset
  echo -n > $lockfile
  
  slot=0
  for slot in $availableslots #loop through the 3/5 vpn slots
    do
      
      clear
      echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v$version | $(date)                                         ${CClear}\n"
      echo -e "${CGreen}[VPN Connection Reset Commencing]"
      echo ""
      echo -e "${CGreen}[Checking VPN Slot $slot]"
      echo ""
      sleep 2
      
      #determine if the slot is monitored and reset it
      if [ "$((VPN$slot))" == "1" ]; then
        
        if [ $refreshserverlists -eq 1 ]; then
          if [ -f /jffs/addons/vpnmon-r3.d/vr3svr$slot.txt ]; then
            echo -e "${CGreen}[Executing Custom Server List Script for VPN Slot $slot]${CClear}"
            slottmp="automation${slot}"
            eval slottmp="\$${slottmp}"
            if [ -z $slottmp ] || [ $slottmp == "" ]; then
              echo ""
              echo -e "${CGreen}[Custom VPN Client Server Query not found for VPN Slot $slot]${CClear}"
            else
              automationunenc=$(echo "$slottmp" | openssl enc -d -base64 -A)
              echo ""
              echo -e "${CClear}Running: $automationunenc"
              echo ""
              eval "$automationunenc" > /jffs/addons/vpnmon-r3.d/vr3svr$slot.txt
              if [ -f /jffs/addons/vpnmon-r3.d/vr3svr$slot.txt ]; then
                dlcnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr$slot.txt | wc -l) >/dev/null 2>&1 
                if [ $dlcnt -lt 1 ]; then 
                  dlcnt=0
                elif [ -z $dlcnt ]; then 
                  dlcnt=0
                fi
              else
                dlcnt=0
              fi
              echo -e "${CGreen}[$dlcnt Rows Retrieved From Source]${CClear}"
              echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: Custom VPN Client Server List Query Executed for VPN Slot $slot ($dlcnt rows)" >> $logfile
              sleep 3
            fi
          else
            echo ""
            echo -e "${CRed}[Custom VPN Client Server List File not found for VPN Slot $slot]${CClear}"
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: Custom VPN Client Server List File not found for VPN Slot $slot" >> $logfile
            sleep 3
          fi
        fi
        
        restartvpn $slot
        
      fi
          
  done
  
  restartrouting
  
  # Clean up lockfile
  rm $lockfile >/dev/null 2>&1
  
  echo -e "\n${CClear}"
  exit 0

}
# -------------------------------------------------------------------------------------------------------------------------
# Find the VPN city

getvpnip()
{
  ubsync=""
  TUN="tun1"$1
  icanhazvpnip=$($timeoutcmd$timeoutsec nvram get vpn_client$1_rip)
  if [ -z $icanhazvpnip ] || [ "$icanhazvpnip" == "unknown" ]; then
    icanhazvpnip="curl --silent --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com" # Grab the public IP of the VPN Connection
    icanhazvpnip="$(eval $icanhazvpnip)"; if echo $icanhazvpnip | grep -qoE 'Internet|traffic|Error|error'; then icanhazvpnip="0.0.0.0"; fi
  fi
  
  if [ -z $icanhazvpnip ] || [ "$icanhazvpnip" == "" ]; then
    vpnip="000.000.000.000"
    return
  else
    vpnip=$(printf '%03d.%03d.%03d.%03d'  ${icanhazvpnip//./ })
  fi

  if [ $unboundclient -ne 0 ] && [ $unboundclient -eq $1 ]; then
  
    if [ $ResolverTimer -eq 1 ]; then
      ResolverTimer=0
      ubsync="${CYellow}-?[UB]${CClear}"
    else
      # Huge thanks to @SomewhereOverTheRainbow for his expertise in troublshooting and coming up with this DNS Resolver methodology!
      DNSResolver="$({ unbound-control flush whoami.akamai.net >/dev/null 2>&1; } && dig whoami.akamai.net +short @"$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{split($4, ip_addr, ":");if(substr($4,11) !~ /.*953.*/)print ip_addr[1];if(substr($4,11) !~ /.*953.*/)exit}')" -p "$(netstat -nlp 2>/dev/null | awk '/.*(unbound){1}.*/{if(substr($4,11) !~ /.*953.*/)print substr($4,11);if(substr($4,11) !~ /.*953.*/)exit}')" 2>/dev/null)"

      if [ -z "$DNSResolver" ]; then
        ubsync="${CRed}-X[UB]${CClear}"
      # rudimentary check to make sure value coming back is in the format of an IP address... Don't care if it's more than 255.
      elif expr "$DNSResolver" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        # If the DNS resolver and public VPN IP address don't match in our Unbound scenario, reset!
        if [ "$DNSResolver" != "$icanhazvpnip" ]; then
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

  # Insert bogus IP if screenshotmode is on
  if [ "$screenshotmode" == "1" ]; then
    vpnip="123.456.789.012"
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Find and remember the VPN city so it doesn't have to make successive API lookups

getvpncity()
{
  
  if [ "$icanhazvpnip" == "0.0.0.0" ]; then
    vpncity="Undetermined"
    return
  fi
  
  if [ "$1" == "1" ]; then
    lastvpnip1="$icanhazvpnip"
    if [ "$lastvpnip1" != "$oldvpnip1" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity1=$vpncity
    fi
    vpncity=$vpncity1
    oldvpnip1=$lastvpnip1
  elif [ "$1" == "2" ]; then
    lastvpnip2="$icanhazvpnip"
    if [ "$lastvpnip2" != "$oldvpnip2" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity2=$vpncity
    fi
    vpncity=$vpncity2
    oldvpnip2=$lastvpnip2
  elif [ "$1" == "3" ]; then
    lastvpnip3="$icanhazvpnip"
    if [ "$lastvpnip3" != "$oldvpnip3" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity3=$vpncity
    fi
    vpncity=$vpncity3
    oldvpnip3=$lastvpnip3
  elif [ "$1" == "4" ]; then
    lastvpnip4="$icanhazvpnip"
    if [ "$lastvpnip4" != "$oldvpnip4" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity4=$vpncity
    fi
    vpncity=$vpncity4
    oldvpnip4=$lastvpnip4
  elif [ "$1" == "5" ]; then
    lastvpnip5="$icanhazvpnip"
    if [ "$lastvpnip5" != "$oldvpnip5" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
      citychange="${CGreen}- NEW ${CClear}"
      vpncity5=$vpncity
    fi
    vpncity=$vpncity5
    oldvpnip5=$lastvpnip5
  fi
  
  # Insert bogus City if screenshotmode is on
  if [ "$screenshotmode" == "1" ]; then
    vpncity="Gotham City"
  fi
  
}

# -------------------------------------------------------------------------------------------------------------------------
# Check health of the vpn connection using PING and CURL

checkvpn() 
{

  CNT=0
  TRIES=3
  TUN="tun1"$1

  while [ $CNT -lt $TRIES ]; do # Loop through number of tries
    ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings
    RC=$?
    ICANHAZIP=$(curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
    IC=$?
    if [ $RC -eq 0 ] && [ $IC -eq 0 ]; then  # If both ping/curl come back successful, then proceed
      vpnping=$(ping -I $TUN -c 1 -W 2 $PINGHOST | awk -F'time=| ms' 'NF==3{print $(NF-1)}' | sort -rn) > /dev/null 2>&1
      VP=$?
      if [ $VP -eq 0 ]; then
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
      CNT=$((CNT+1))
      printf "\33[2K\r"
      printf "\r${InvDkGray} ${CWhite} VPN$1${CClear} [Attempt $CNT]"
      sleep 1 # Giving the VPN a chance to recover a certain number of times

      if [ $CNT -eq $TRIES ];then # But if it fails, report back that we have an issue requiring a VPN reset
        printf "\33[2K\r"
        vpnping=0
        vpnhealth="${CRed}[FAIL]${CClear}"
        vpnindicator="${InvRed} ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - WARNING: VPN$1 failed to respond" >> $logfile
        if [ "$((VPN$1))" == "1" ]; then
          resetvpn=$1
        fi
      fi
    fi
  done

}

# -------------------------------------------------------------------------------------------------------------------------

# Checkwan is a function that checks the viability of the current WAN connection and will loop until the WAN connection is restored.
checkwan()
{

  # Using Google's 8.8.8.8 server to test for WAN connectivity over verified SSL Handshake
  wandownbreakertrip=0
  testssl="8.8.8.8"
  
  printf "\33[2K\r"
  printf "\r${InvYellow} ${CClear} [Checking WAN Connectivity]..."
  
  #Run main checkwan loop
  while true; do

    # Check the actual WAN State from NVRAM before running connectivity test, or insert itself into loop after failing an SSL handshake test
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ] || [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
      then

        # Test the active WAN connection using 443 and verifying a handshake... if this fails, then the WAN connection is most likely down... or Google is down ;)
        if ($timeoutcmd$timeoutlng nc -w3 $testssl 443 >/dev/null 2>&1 && echo | $timeoutcmd$timeoutlng openssl s_client -connect $testssl:443 >/dev/null 2>&1 | awk 'handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 } $1 $2 == "SSLhandshake" { handshake = 1 }' >/dev/null 2>&1)
        #if ($timeoutcmd$timeoutlng nc -w1 $testssl 443 >/dev/null 2>&1 && echo | $timeoutcmd$timeoutlng openssl s_client -connect $testssl:443 >/dev/null 2>&1 | awk '$1 == "SSL" && $2 == "handshake" { handshake = 1 } handshake && $1 == "Verification:" { ok = $2; exit } END { exit ok != "OK" }' >/dev/null 2>&1); then
          then
            printf "\r${InvGreen} ${CClear} [Checking WAN Connectivity]...ACTIVE"
            sleep 1
            printf "\33[2K\r"
            return
          else
            wandownbreakertrip=1
            echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: WAN Connectivity Issue Detected" >> $logfile
        fi
      else
        wandownbreakertrip=1
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: WAN Connectivity Issue Detected" >> $logfile
    fi

    if [ "$wandownbreakertrip" == "1" ]
      then
        # The WAN is most likely down, and keep looping through until NVRAM reports that it's back up
        while [ "$wandownbreakertrip" == "1" ]; do
 
          if [ "$availableslots" == "1 2 3" ]; then
            state1="$(_VPN_GetClientState_ 1)"
            state2="$(_VPN_GetClientState_ 2)"
            state3="$(_VPN_GetClientState_ 3)"
            printf "\r${InvGreen} ${CClear} [Confirming VPN Clients Disconnected]... 1:$state1 2:$state2 3:$state3                         "
            sleep 3
          elif [ "$availableslots" == "1 2 3 4 5" ]; then
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
              echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: WAN DOWN" >> $logfile
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
      if [ "$wandownbreakertrip" == "2" ]
        then
          echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - WARNING:  WAN Link Detected -- Trying to reconnect/Reset VPN" >> $logfile
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
          exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

  done
}

# -------------------------------------------------------------------------------------------------------------------------

# wancheck is a function that checks each wan connection to see if its active, and performs a ping and a city lookup...
wancheck() {

  WANIF=$1
  WANIFNAME=$(get_wan_setting ifname)
  DUALWANMODE=$($timeoutcmd$timeoutsec nvram get wans_mode)

  # If WAN 0 or 1 is connected, then proceed, else display that it's inactive
  if [ "$WANIF" == "0" ]; then
    if [ "$($timeoutcmd$timeoutsec nvram get wan0_state_t)" -eq 2 ]
      then
        # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
        WAN0IFNAME=$(get_wan_setting0 ifname)

        # Ping through the WAN interface
        if [ "$WANIFNAME" == "$WAN0IFNAME" ] || [ "$DUALWANMODE" == "lb" ]; then
          WAN0PING=$(ping -I $WAN0IFNAME -c 1 $PINGHOST | awk -F'[/=]' 'END{print $5}') > /dev/null 2>&1
          WAN0PING=$(awk "BEGIN {printf \"[%08.3f]\", ${WAN0PING}}")
        else
          WAN0PING="FAILOVER"
        fi

        if [ -z "$WAN0PING" ]; then WAN0PING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

        # Get the public IP of the WAN, determine the city from it, and display it on screen
        if [ "$WAN0IP" == "" ] || [ -z "$WAN0IP" ]; then
          WAN0IP=$(curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail --interface $WAN0IFNAME --request GET --url https://ipv4.icanhazip.com)
          WAN0CITY="curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --request GET --url http://ip-api.com/json/$WAN0IP | jq --raw-output .city"
          WAN0CITY="$(eval $WAN0CITY)"; if echo $WAN0CITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then WAN0CITY="$WAN0IP"; fi
          WAN0IP=$(printf '%03d.%03d.%03d.%03d'  ${WAN0IP//./ })
        fi
        
        # Insert bogus IP and City if screenshotmode is on
        if [ "$screenshotmode" == "1" ]; then
          WAN0CITY="Metropolis"
          WAN0IP="101.202.303.404"
        fi

        if [ "$WAN0PING" == "FAILOVER" ]; then
          echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN0${CClear} | ${CGreen}[X]${CClear} | "
          printf "%-6s" $WAN0IFNAME
          echo -e " | ${CGreen}[ OK ]${CClear} | Failover     | $WAN0IP | $WAN0PING | $WAN0CITY"
        else
          echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN0${CClear} | ${CGreen}[X]${CClear} | "
          printf "%-6s" $WAN0IFNAME
          echo -e " | ${CGreen}[ OK ]${CClear} | Active       | $WAN0IP | $WAN0PING | $WAN0CITY"
        fi

      else
        echo -e "${InvDkGray}${CWhite}  WAN0${CClear} | ${CGreen}[X]${CClear} | ${CDkGray}[n/a]${CClear}  | ${CDkGray}[n/a ]${CClear} | Inactive     | ${CDkGray}[n/a]${CClear}           | ${CDkGray}[n/a]${CClear}      | ${CDkGray}[n/a]${CClear}"
    fi
  fi

  if [ "$WANIF" == "1" ]; then
    if [ "$($timeoutcmd$timeoutsec nvram get wan1_state_t)" -eq 2 ]
      then
        # Call the get_wan_setting function courtesy of @dave14305 and using this interface name to ping and get a city name from
        WAN1IFNAME=$(get_wan_setting1 ifname)

        # Ping through the WAN interface
        if [ "$WANIFNAME" == "$WAN1IFNAME" ] || [ "$DUALWANMODE" == "lb" ]; then
          WAN1PING=$(ping -I $WAN1IFNAME -c 1 $PINGHOST | awk -F'[/=]' 'END{print $5}') > /dev/null 2>&1
          WAN1PING=$(awk "BEGIN {printf \"[%08.3f]\", ${WAN1PING}}")
        else
          WAN1PING="FAILOVER"
        fi

        if [ -z "$WAN1PING" ]; then WAN1PING=1; fi # On that rare occasion where it's unable to get the Ping time, assign 1

        # Get the public IP of the WAN, determine the city from it, and display it on screen
        if [ "$WAN1IP" == "" ] || [ -z "$WAN1IP" ]; then
          WAN1IP=$(curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail --interface $WAN1IFNAME --request GET --url https://ipv4.icanhazip.com)
          WAN1CITY="curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --request GET --url http://ip-api.com/json/$WAN1IP | jq --raw-output .city"
          WAN1CITY="$(eval $WAN1CITY)"; if echo $WAN1CITY | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then WAN1CITY="$WAN1IP"; fi
          WAN1IP=$(printf '%03d.%03d.%03d.%03d'  ${WAN1IP//./ })
        fi

        if [ "$WAN1PING" == "FAILOVER" ]; then
          echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN1${CClear} | ${CGreen}[X]${CClear} | "
          printf "%-6s" $WAN1IFNAME
          echo -e " | ${CGreen}[ OK ]${CClear} | Failover     | $WAN1IP | $WAN1PING | $WAN1CITY"
        else
          echo -en "${InvGreen} ${InvDkGray}${CWhite} WAN1${CClear} | ${CGreen}[X]${CClear} | "
          printf "%-6s" $WAN1IFNAME
          echo -e " | ${CGreen}[ OK ]${CClear} | Active       | $WAN1IP | $WAN1PING | $WAN1CITY"
        fi

      else
        echo -e "${InvDkGray}${CWhite}  WAN1${CClear} | ${CGreen}[X]${CClear} | ${CDkGray}[n/a]${CClear}  | ${CDkGray}[n/a ]${CClear} | Inactive     | ${CDkGray}[n/a]${CClear}           | ${CDkGray}[n/a]${CClear}      | ${CDkGray}[n/a]${CClear}"
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
} # get_wan_setting

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
} # get_wan_setting

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
} # get_wan_setting

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the operations menu

displayopsmenu()
{

    #scheduler colors and indicators
    if [ "$schedule" == "0" ]; then
      schedtime="${CDkGray}01:00${CClear}"
    elif [ "$schedule" == "1" ]; then
      schedhrs=$(awk "BEGIN {printf \"%02.f\",${schedulehrs}}")
      schedmin=$(awk "BEGIN {printf \"%02.f\",${schedulemin}}")
      schedtime="${CGreen}$schedhrs:$schedmin${CClear}"
    fi
    
    #autostart colors and indicators
    if [ "$autostart" == "0" ]; then
      rebootprot="${CDkGray}Disabled${CClear}"
    elif [ "$autostart" == "1" ]; then
      rebootprot="${CGreen}Enabled${CClear}"
    fi
    
    if [ $logsize -gt 0 ]; then
      logsizefmt=$(awk "BEGIN {printf \"%04.f\",${logsize}}")
    else
      logsizefmt="${CDkGray}n/a ${CClear}"
    fi
    
    #display operations menu
    echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                              ${CClear}"
    echo -e "${InvGreen} ${CClear} Reset/Reconnect VPN 1:${CGreen}(1)${CClear} 2:${CGreen}(2)${CClear} 3:${CGreen}(3)${CClear} 4:${CGreen}(4)${CClear} 5:${CGreen}(5)${CClear}    ${InvGreen} ${CClear} ${CGreen}(C)${CClear}onfiguration Menu / Main Setup Menu${CClear}"
    echo -e "${InvGreen} ${CClear} Stop/Unmonitor  VPN 1:${CGreen}(!)${CClear} 2:${CGreen}(@)${CClear} 3:${CGreen}(#)${CClear} 4:${CGreen}($)${CClear} 5:${CGreen}(%)${CClear}    ${InvGreen} ${CClear} ${CGreen}(R)${CClear}eset VPN CRON Time Scheduler: $schedtime${CClear}"
    echo -e "${InvGreen} ${CClear} Enable/Disable ${CGreen}(M)${CClear}onitored VPN Slots                 ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim Log Size (rows): ${CGreen}$logsizefmt${CClear}"
    echo -e "${InvGreen} ${CClear} Update/Maintain ${CGreen}(V)${CClear}PN Server Lists                   ${InvGreen} ${CClear} ${CGreen}(A)${CClear}utostart VPNMON-R3 on Reboot: $rebootprot${CClear}"
    echo -e "${InvGreen} ${CClear} Edit/R${CGreen}(U)${CClear}n Server List Automation                    ${InvGreen} ${CClear} ${CGreen}(T)${CClear}imer VPN Check Loop Interval: ${CGreen}${timerloop}sec${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""

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

# Check for updates
updatecheck

# Check and see if any commandline option is being used
if [ $# -eq 0 ]
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
  echo ""
  echo " -h | -help (this output)"
  echo " -setup (displays the setup menu)"
  echo " -reset (resets vpn connections and exits)"
  echo " -bw (runs vpnmon-r3 in monochrome mode)"
  echo " -screen (runs vpnmon-r3 in screen background)"
  echo ""
  echo -e "${CClear}"
  exit 0
fi

# Check to see if a second command is being passed to remove color
if [ "$1" == "-bw" ] || [ "$2" == "-bw" ]
  then
    blackwhite
fi

# Check to see if the -now parameter is being called to bypass the screen timer
if [ "$2" == "-now" ]
  then
    bypassscreentimer=1
fi

# Check to see if the setup option is being called
if [ "$1" == "-setup" ]
  then
    vsetup
    exit 0
fi

# Check to see if the reset option is being called
if [ "$1" == "-reset" ]
  then
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Reset initiated through -RESET switch" >> $logfile
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

# Check to see if the noswitch  option is being called
if [ "$1" == "-noswitch" ]
  then
    clear #last switch before the main program starts
    firstrun=1
    
    # Clean up lockfile
    rm $lockfile >/dev/null 2>&1
    
    if [ ! -f $cfgpath ] && [ ! -f "/opt/bin/timeout" ] && [ ! -f "/opt/sbin/screen" ] && [ ! -f "/opt/bin/jq" ]; then
      echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3 -setup' first.${CClear}"
      echo ""
      echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 is not configured. Please run the setup/configuration utility" >> $logfile
      exit 0
    fi
fi

while true; do
  
  # Grab the VPNMON-R3 config file and read it in
  if [ -f $config ]; then
    source $config
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]; then
    source /jffs/addons/vpnmon-r3.d/vr3clients.txt
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Client Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
  createconfigs
  
  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3timers.txt ]; then
    source /jffs/addons/vpnmon-r3.d/vr3timers.txt
  else
    clear
    echo -e "${CRed}ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Timer Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
  if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
    then
      timeoutcmd="timeout "
      timeoutsec="10"
      timeoutlng="60"
    else
      timeoutcmd=""
      timeoutsec=""
      timeoutlng=""
  fi
  
  #Set variables
  resetvpn=0
  
  #Check to see if a reset is currently underway
  lockcheck
  
  clear #display the header
  
  if [ "$hideoptions" == "0" ]; then
    resettimer=0
    displayopsmenu
  else
    resettimer=0
  fi
    
  tzone=$(date +%Z)
  tzonechars=$(echo ${#tzone})

  if [ $tzonechars = 1 ]; then tzspaces="        ";
  elif [ $tzonechars = 2 ]; then tzspaces="       ";
  elif [ $tzonechars = 3 ]; then tzspaces="      ";
  elif [ $tzonechars = 4 ]; then tzspaces="     ";
  elif [ $tzonechars = 5 ]; then tzspaces="    "; fi
  
  #Display VPNMON-R3 client header
  echo -en "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v"
  printf "%-6s" $version
  echo -e "                 ${CGreen}(S)${CWhite}how/${CGreen}(H)${CWhite}ide Operations Menu ${InvDkGray}        $tzspaces$(date) ${CClear}"

  #Display VPNMON-R2 Found Warning
  if [ -f /jffs/scripts/vpnmon-r2.sh ]; then
    echo -e "${InvYellow} ${InvRed}${CWhite} VPNMON-R2 Install Detected. Support and availability for R2 is being sunset. Press (X) for Uninstall Menu.   ${CClear}"
  fi

  #Display VPNMON-R3 Update Notifications
  if [ "$UpdateNotify" != "0" ]; then echo -e "$UpdateNotify\n"; else echo -e "${CClear}"; fi

  #If WAN Monitoring is enabled, test WAN connection and show the following grid
  if [ "$monitorwan" == "1" ] && [ "$firstrun" == "1" ]; then
    #Check to see if the WAN is up
    checkwan
    firstrun=0
  fi
  
  if [ "$monitorwan" == "1" ] && [ "$firstrun" = "0" ]; then
    #Display WAN ports grid
    echo -e "${CClear}  Port | Mon | IFace  | Health | WAN State    | Public WAN IP   | Ping-->WAN | City Exit"
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"

    #Cycle through the WANCheck connection function to display ping/city info
    wans=0
    for wans in 0 1
      do
        wancheck $wans
    done
    echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"
    echo ""
    echo -e "${InvDkGray}                                                                                                               ${CClear}"
    echo ""
  fi
  
  #Display VPN client slot grid
  if [ "$unboundclient" != "0" ]; then
    echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | City Exit / Time / UB"
  else
    echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | Ping-->VPN | City Exit / Time"
  fi
  echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"
  
  i=0
  for i in $availableslots #loop through the 3/5 vpn slots
    do
      
      #Set variables
      citychange=""
      
      #determine if the slot is monitored
      if [ "$((VPN$i))" == "0" ]; then
        monitored="[ ]"
      elif [ "$((VPN$i))" == "1" ]; then
        monitored="${CGreen}[X]${CClear}"
      fi
      
      #determine the vpn state, and if connected, get vpn IP and city      
      vpnstate="$(_VPN_GetClientState_ $i)"
      
      if [ "$vpnstate" == "0" ]; then
        vpnstate="Disconnected"
        vpnhealth="${CDkGray}[n/a ]${CClear}"
        vpnindicator="${InvDkGray} ${CClear}"
        vpnip="${CDkGray}[n/a]          ${CClear}"
        vpncity="${CDkGray}[n/a]${CClear}"
        svrping="${CDkGray}[n/a]     ${CClear}"
      elif [ "$vpnstate" == "-1" ]; then
        vpnstate="Error State "
        vpnhealth="${CDkGray}[n/a ]${CClear}"
        vpnindicator="${InvDkGray} ${CClear}"
        vpnip="${CDkGray}[n/a]          ${CClear}"
        vpncity="${CDkGray}[n/a]${CClear}"
        svrping="${CDkGray}[n/a]     ${CClear}"
      elif [ "$vpnstate" == "1" ]; then
        vpnstate="Connecting  "
        vpnhealth="${CDkGray}[n/a ]${CClear}"
        vpnindicator="${InvYellow} ${CClear}"
        vpnip="${CDkGray}[n/a]          ${CClear}"
        vpncity="${CDkGray}[n/a]${CClear}"
        svrping="${CDkGray}[n/a]     ${CClear}"
      elif [ "$vpnstate" == "2" ]; then
        vpnstate="Connected   "
        checkvpn $i
        getvpnip $i
        getvpncity $i
        if [ -z $vpnping ] || [ "$vpnping" == "" ]; then
          svrping="${CRed}[PING ERR]${CClear}"
          vpnhealth="${CYellow}[UNKN]${CClear}"
          vpnindicator="${InvYellow} ${CClear}"
        else
          svrping=$(awk "BEGIN {printf \"[%08.3f]\", ${vpnping}}")
        fi
      else
        vpnstate="Unknown     "
        vpnhealth="${CDkGray}[n/a ]${CClear}"
        vpnindicator="${InvDkGray} ${CClear}"
        vpnip="${CDkGray}[n/a]          ${CClear}"
        vpncity="${CDkGray}[n/a]${CClear}"
        svrping="${CDkGray}[n/a]     ${CClear}"
      fi 
      
      #Determine how many server entries are in each of the vpn slot alternate server files
      if [ -f /jffs/addons/vpnmon-r3.d/vr3svr$i.txt ]; then
        servercnt=$(cat /jffs/addons/vpnmon-r3.d/vr3svr$i.txt | wc -l) >/dev/null 2>&1 
          if [ $servercnt -lt 1 ]; then 
            servercnt="${CRed}[0000]${CClear}"
          elif [ -z $servercnt ]; then 
            servercnt="${CRed}[0000]${CClear}"
          else
            servercnt=$(awk "BEGIN {printf \"[%04.f]\",${servercnt}}")
          fi
      else
        servercnt="${CRed}[0000]${CClear}"
      fi
      
      #Calculate connected time for current VPN slot
      if [ $((VPNTIMER$i)) == "0" ] || [ "$((VPN$i))" == "0" ]; then
        sincelastreset=""
      else
        currtime=$(date +%s)
        timediff=$((currtime-VPNTIMER$i))
        sincelastreset=$(printf ': %dd %02dh:%02dm\n' $(($timediff/86400)) $(($timediff%86400/3600)) $(($timediff%3600/60)))
      fi
      
      #print the results of all data gathered sofar
      echo -e "$vpnindicator${InvDkGray}${CWhite} VPN$i${CClear} | $monitored | $servercnt | $vpnhealth | $vpnstate | $vpnip | $svrping | $vpncity$sincelastreset $citychange$ubsync"
            
      #if a vpn is monitored and disconnected, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$vpnstate" == "Disconnected" ]; then #reconnect
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - WARNING: VPN$i has disconnected" >> $logfile
        echo ""
        printf "\33[2K\r"
        
        #display a standard timer
        timer=0
        while [ $timer -ne 5 ]
        do
          timer=$(($timer+1))
          preparebar 46 "|"
          progressbarpause $timer 5 "" "s" "Standard"
          #sleep 1
        done
        printf "\33[2K\r"
        
        restartvpn $i
        restartrouting
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi

      #if a vpn is monitored and in error state, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$vpnstate" == "Error State " ]; then #reconnect
        echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - WARNING: VPN$i is in an error state and being reconnected" >> $logfile
        echo ""
        printf "\33[2K\r"
        
        #display a standard timer
        timer=0
        while [ $timer -ne 5 ]
        do
          timer=$(($timer+1))
          preparebar 46 "|"
          progressbarpause $timer 5 "" "s" "Standard"
          #sleep 1
        done
        printf "\33[2K\r"
        
        restartvpn $i
        restartrouting
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi
      
      #if a vpn is monitored and not responsive, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$resetvpn" != "0" ]; then #reconnect
        echo ""
        printf "\33[2K\r"
        
        #display a standard timer
        timer=0
        while [ $timer -ne 5 ]
        do
          timer=$(($timer+1))
          preparebar 46 "|"
          progressbarpause $timer 5 "" "s" "Standard"
          #sleep 1
        done
        printf "\33[2K\r"
        
        restartvpn $resetvpn
        restartrouting
        exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
        
      fi
      
      #Reset variables
      ubsync=""
      sincelastreset=""

  done

  echo -e "-------|-----|--------|--------|--------------|-----------------|------------|---------------------------------"
  echo ""

  #display a standard timer
  timer=0
  while [ $timer -ne $timerloop ]
    do
      timer=$(($timer+1))
      preparebar 46 "|"
      progressbaroverride $timer $timerloop "" "s" "Standard"
      lockcheck #Check to see if a reset is currently underway
      if [ "$resettimer" == "1" ]; then timer=$timerloop; fi
  done
  
  #Check to see if a reset is currently underway
  lockcheck
  
  #if Unbound is active and out of sync, try to restart it
  if [ "$unboundclient" != "0" ] && [ "$ResolverTimer" == "1" ]; then
    echo ""
    echo -e "$(date +'%b %d %Y %X') $($timeoutcmd$timeoutsec nvram get lan_hostname) VPNMON-R3[$$] - WARNING: VPN$unboundreset is out of sync with Unbound DNS Resolver" >> $logfile
    echo ""
    printf "\33[2K\r"
        
    #display a standard timer
    timer=0
    while [ $timer -ne 5 ]
    do
      timer=$(($timer+1))
      preparebar 46 "|"
      progressbarpause $timer 5 "" "s" "Standard"
      #sleep 1
    done
    printf "\33[2K\r"
        
    restartvpn $unboundreset
    restartrouting
    exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    
  fi
      
  #Check to see if the WAN is up
  if [ "$monitorwan" == "1" ] && [ "$bypasswancheck" == "0" ]; then
    checkwan
  fi
  
  firstrun=0

done
echo -e "${CClear}"
exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
