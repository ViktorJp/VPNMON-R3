#!/bin/sh

# VPNMON-R3 v0.1b (VPNMON-R3.SH) is an all-in-one script that is optimized to maintain multiple VPN connections and is
# able to provide for the capabilities to randomly reconnect using a specified server list containing the servers of your
# choice. Special care has been taken to ensure that only the VPN connections you want to have monitored are tended to.
# This script will check the health of up to 5 VPN connections on a regular interval to see if monitored VPN conenctions
# are connected, and sends a ping to a host of your choice through each active connection. If it finds that a connection
# has been lost, it will execute a series of commands that will kill that single VPN client, and randomly picks one of
# your specified servers to reconnect to for each VPN client.

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

#Static Variables - please do not change
version="0.1b"                                                  # Version tracker
beta=1                                                          # Beta switch
apppath="/jffs/scripts/vpnmon-r3.sh"                            # Static path to the app
logfile="/jffs/addons/vpnmon-r3.d/vpnmon-r3.log"                # Static path to the log
dlverpath="/jffs/addons/vpnmon-r3.d/version.txt"                # Static path to the version file
config="/jffs/addons/vpnmon-r3.d/vpnmon-r3.cfg"                 # Static path to the config file		
availableslots="1 2 3 4 5"                                      # Available slots tracker
PINGHOST="8.8.8.8"                                              # Ping host
logsize=2000                                                    # Log file size in rows
timerloop=60                                                    # Timer loop in sec
schedule=0                                                      # Scheduler enable y/n
schedulehrs=1                                                   # Scheduler hours
schedulemin=0                                                   # Scheduler mins
autostart=0                                                     # Auto start on router reboot y/n

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
    read -p "[y/n]? " -n 1 -r yn
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
  # $1 - bar length
  # $2 - bar char
  #printf "\n"
  barlen=$1
  barspaces=$(printf "%*s" "$1")
  barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

progressbaroverride() 
{
  # $1 - number (-1 for clearing the bar)
  # $2 - max number
  # $3 - system name
  # $4 - measurement
  # $5 - standard/reverse progressbar
  # $6 - alternate display values
  # $7 - alternate value for progressbar exceeding 100%

  insertspc=" "

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
          [Ss]) resettimer=1; hideoptions=0;;
          [Hh]) resettimer=1; hideoptions=1;;
          [1]) restartvpn 1;;
          [2]) restartvpn 2;;
          [3]) restartvpn 3;;
          [4]) restartvpn 4;;
          [5]) restartvpn 5;;
          [Mm]) vpnslots;;
          [Vv]) vpnserverlistmaint;;
          [Tt]) timerloopconfig;;
          [Rr]) schedulevpnreset;;
          [Aa]) autostart;;
          [Ll]) vlogs;;
          [Cc]) vsetup;;
          [Ee])  # Exit gracefully
                echo -e "${CClear}\n"
                exit 0
                ;;
      esac
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

  # Create initial vr3clients.txt file
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
        if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ]; then
          vconfig
        else
          clear
          echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Dependencies                                                                  ${CClear}"
          echo -e "${InvGreen} ${CClear}"
          echo -e "${InvGreen} ${CClear} Missing dependencies required by VPNMON-R3 will be installed during this process."         
          echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
          echo ""
          echo -e "VPNMON-R3 has some dependencies in order to function correctly, namely, CoreUtils-Timeout"
          echo -e "and the Screen utility. These utilities require you to have Entware already installed"
          echo -e "using the AMTM tool. If Entware is present, the Timeout and Screen utilities will"
          echo -e "automatically be downloaded and installed during this process."
          echo ""
          echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
          echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router model."
          echo ""
          echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
          echo -e "directly on the router itself, instead of running your commands or a script from a network-"
          echo -e "attached SSH client. This can provide greater stability due to it running on the router"
          echo -e "itself."
          echo ""
          [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
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
        echo -e "Would you like to re-install the CoreUtils-Timeout and the Screen utility? These"
        echo -e "utilities require you to have Entware already installed using the AMTM tool. If Entware"
        echo -e "is present, the Timeout and Screen utilities will be uninstalled, downloaded and re-"
        echo -e "installed during this setup process..."
        echo ""
        echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
        echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router"
        echo -e "model."
        echo ""
        echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone environment"
        echo -e "directly on the router itself, instead of running your commands or a script from a"
        echo -e "network-attached SSH client. This can provide greater stability due to it running on"
        echo -e "the router itself."
        echo ""
        [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
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
      [Ee]) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
    esac
done

}

# -------------------------------------------------------------------------------------------------------------------------
# vconfig is a function that provides a UI to choose various options for vpnmon-r3

vconfig() 
{

while true; do

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
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
  echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  read -p "Please select? (1-3, e=Exit): " SelectSlot
    case $SelectSlot in
      1)
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Number of VPN Client Slots Available on Router                                        ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate how many VPN client slots your router is configured with. Certain${CClear}"
        echo -e "${InvGreen} ${CClear} older model routers can only handle a maximum of 3 client slots, while newer models${CClear}"
        echo -e "${InvGreen} ${CClear} can handle 5. (Default = 5 VPN client slots)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$availableslots${CClear}"
        echo ""
        read -p "Please enter value (3 or 5)? (e=Exit): " EnterAvailableSlots
          if [ "$EnterAvailableSlots" == "3" ]; then
            availableslots="1 2 3"
            echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            saveconfig
          elif [ "$EnterAvailableSlots" == "5" ]; then
            availableslots="1 2 3 4 5"
            echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
            saveconfig
          elif [ "$EnterAvailableSlots" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          else availableslots="1 2 3 4 5"
            echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New Available VPN Client Slot Configuration saved as: $availableslots" >> $logfile
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
        echo -e "${InvGreen} ${CClear} local access and connectivity situation. (Default = 8.8.8.8)${CClear}"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$PINGHOST${CClear}"
        echo ""
        read -p "Please enter valid IP4 address? (e=Exit): " NEWPINGHOST
          if [ "$NEWPINGHOST" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          else PINGHOST=$NEWPINGHOST
            echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New custom PING host entered: $PINGHOST" >> $logfile
            saveconfig
          fi
      ;;

  		3) 
        clear
        echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom Event Log Size                                                                 ${CClear}"
        echo -e "${InvGreen} ${CClear}"
        echo -e "${InvGreen} ${CClear} Please indicate below how large you would like your Event Log to grow. I'm a poet${CClear}"
        echo -e "${InvGreen} ${CClear} and didn't even know it. By default, with 2000 rows, you will have many months of${CClear}"
        echo -e "${InvGreen} ${CClear} Event Log data. Use 0 to disable, max number of rows is 9999. (Default = 2000)"
        echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
        echo ""
        echo -e "${CClear}Current: ${CGreen}$logsize${CClear}"
        echo ""
        read -p "Please enter Log Size (in rows)? (0-9999, e=Exit): " NEWLOGSIZE

          if [ "$NEWLOGSIZE" == "e" ]; then
            echo -e "\n[Exiting]"; sleep 2
          elif [ $NEWLOGSIZE -ge 0 ] && [ $NEWLOGSIZE -le 9999 ]; then
            logsize=$NEWLOGSIZE
            echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New custom Event Log Size entered (in rows): $logsize" >> $logfile
            saveconfig
          else
            logsize=2000
            echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New custom Event Log Size entered (in rows): $logsize" >> $logfile
            saveconfig			    
          fi
      ;;

      [Ee]) break ;;

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
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3-$DLversion.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Successfully downloaded and installed VPNMON-R3 v$DLversion" >> $logfile
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
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/vpnmon-r3-$DLversion.sh" -o "/jffs/scripts/vpnmon-r3.sh" && chmod 755 "/jffs/scripts/vpnmon-r3.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Successfully downloaded and installed VPNMON-R3 v$DLversion" >> $logfile
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
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/VPNMON-R3/main/version.txt" -o "/jffs/addons/vpnmon-r3.d/version.txt"

  if [ -f $dlverpath ]
    then
      # Read in its contents for the current version file
      DLversion=$(cat $dlverpath)

      # Compare the new version with the old version and log it
      if [ "$beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLversion" != "$version" ]; then
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$version -> v$DLversion                                                      ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: A new update (v$DLversion) is available to download" >> $logfile
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
        kill 0
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
exec sh /jffs/scripts/vpnmon-r3.sh -noswitch

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
		  echo ""
		  echo -e "${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp${CClear}"
		  echo -e "${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp${CClear}"
		  echo -e "${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3) -${CClear} $VPN3Disp${CClear}"
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
			       echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Client Slot Monitoring configuration saved" >> $logfile
		         exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
		    esac    
    
    elif [ "$availableslots" == "1 2 3 4 5" ]; then
    
	    if [ "$VPN1" == "1" ]; then VPN1Disp="${CGreen}Y${CCyan}"; else VPN1=0; VPN1Disp="${CRed}N${CCyan}"; fi
	    if [ "$VPN2" == "1" ]; then VPN2Disp="${CGreen}Y${CCyan}"; else VPN2=0; VPN2Disp="${CRed}N${CCyan}"; fi
	    if [ "$VPN3" == "1" ]; then VPN3Disp="${CGreen}Y${CCyan}"; else VPN3=0; VPN3Disp="${CRed}N${CCyan}"; fi
	    if [ "$VPN4" == "1" ]; then VPN4Disp="${CGreen}Y${CCyan}"; else VPN4=0; VPN4Disp="${CRed}N${CCyan}"; fi
	    if [ "$VPN5" == "1" ]; then VPN5Disp="${CGreen}Y${CCyan}"; else VPN5=0; VPN5Disp="${CRed}N${CCyan}"; fi
		  echo ""
		  echo -e "${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1) -${CClear} $VPN1Disp${CClear}"
		  echo -e "${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2) -${CClear} $VPN2Disp${CClear}"
		  echo -e "${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3) -${CClear} $VPN3Disp${CClear}"
		  echo -e "${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(4) -${CClear} $VPN4Disp${CClear}"
		  echo -e "${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(5) -${CClear} $VPN5Disp${CClear}"
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
			       echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Client Slot Monitoring configuration saved" >> $logfile
		         exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
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
  echo ""
  echo -e "${InvDkGray}${CWhite}VPN1${CClear} ${CGreen}(1)${CClear}"
	  if [ -f /jffs/addons/vpnmon-r3.d/vr3svr1.txt ]; then
		  iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr1.txt | sed 's/,$/\n/')
			echo -en "Contents: "; printf "%.75s>\n" $iplist
		else
			echo -e "Contents: <blank>"
		fi
	echo ""
  echo -e "${InvDkGray}${CWhite}VPN2${CClear} ${CGreen}(2)${CClear}"
  	if [ -f /jffs/addons/vpnmon-r3.d/vr3svr2.txt ]; then
	    iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr2.txt | sed 's/,$/\n/')
			echo -en "Contents: "; printf "%.75s>\n" $iplist
		else
			echo -e "Contents: <blank>"
		fi
	echo ""
  echo -e "${InvDkGray}${CWhite}VPN3${CClear} ${CGreen}(3)${CClear}"
  	if [ -f /jffs/addons/vpnmon-r3.d/vr3svr3.txt ]; then
    	iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr3.txt | sed 's/,$/\n/')
			echo -en "Contents: "; printf "%.75s>\n" $iplist
		else
			echo -e "Contents: <blank>"
		fi			
	echo ""
	
	if [ "$availableslots" == "1 2 3" ]; then
	  read -p "Please select? (1-3, e=Exit): " SelectSlot
    case $SelectSlot in
      1) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr1.txt;;
      2) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr2.txt;;
      3) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr3.txt;;
      [Ee]) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
    esac
  fi
	
	if [ "$availableslots" == "1 2 3 4 5" ]; then
	  echo -e "${InvDkGray}${CWhite}VPN4${CClear} ${CGreen}(4)${CClear}"
	  	if [ -f /jffs/addons/vpnmon-r3.d/vr3svr4.txt ]; then
	    	iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr4.txt | sed 's/,$/\n/')
				echo -en "Contents: "; printf "%.75s>\n" $iplist
			else
				echo -e "Contents: <blank>"
			fi						
		echo ""
	  echo -e "${InvDkGray}${CWhite}VPN5${CClear} ${CGreen}(5)${CClear}"
	  	if [ -f /jffs/addons/vpnmon-r3.d/vr3svr5.txt ]; then
	   		iplist=$(awk -vORS=, '{ print $1 }' /jffs/addons/vpnmon-r3.d/vr3svr5.txt | sed 's/,$/\n/')
				echo -en "Contents: "; printf "%.75s>\n" $iplist
			else
				echo -e "Contents: <blank>"
			fi						
	  echo ""
  	read -p "Please select? (1-5, e=Exit): " SelectSlot
    case $SelectSlot in
      1) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr1.txt;;
      2) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr2.txt;;
      3) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr3.txt;;
      4) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr4.txt;;
      5) export TERM=linux; nano +999999 --linenumbers /jffs/addons/vpnmon-r3.d/vr3svr5.txt;;
      [Ee]) exec sh /jffs/scripts/vpnmon-r3.sh -noswitch;;
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
  echo ""
  echo -e "${CClear}Current: ${CGreen}$timerloop sec${CClear}"
  echo ""
  read -p "Please enter value (1-999)? (e=Exit): " EnterTimerLoop
    if [ $EnterTimerLoop -gt 0 ] && [ $EnterTimerLoop -le 999 ]; then
    	timerloop=$EnterTimerLoop
    	echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Timer Loop Configuration saved" >> $logfile
    	saveconfig
    	exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    elif [ "$EnterTimerLoop" == "e" ]; then 
    	echo ""
    	exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
    else
    	echo ""
      echo -e "${CRed}ERROR: Invalid entry. Please use a value between 1 and 999"; echo ""
      sleep 3
    fi
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
  echo ""
  if [ "$schedule" == "0" ]; then
  	echo -e "${CClear}Current: ${CRed}Disabled${CClear}"
  elif [ "$schedule" == "1" ]; then
 		schedhrs=$(awk "BEGIN {printf \"%02.f\",${schedulehrs}}")
		schedmin=$(awk "BEGIN {printf \"%02.f\",${schedulemin}}")
		schedtime="${CGreen}$schedhrs:$schedmin${CClear}"
		echo -e "${CClear}Current: ${CGreen}Enabled, Daily @ $schedtime${CClear}"
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
		  echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Reset Schedule Disabled" >> $logfile
      saveconfig
      exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
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
	  echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Reset Schedule Enabled" >> $logfile
	  saveconfig
	  exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
	  
	elif [ "$schedule" == "e" ]; then
		exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
	
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
  echo ""
  if [ "$autostart" == "0" ]; then
  	echo -e "${CClear}Current: ${CRed}Disabled${CClear}"
  elif [ "$autostart" == "1" ]; then
		echo -e "${CClear}Current: ${CGreen}Enabled${CClear}"
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
		  sleep 2
		  echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Reboot Protection Disabled" >> $logfile
		  saveconfig
		  exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
		fi

	elif [ "$autostart" == "1" ]; then

	  if [ -f /jffs/scripts/post-mount ]; then

	    if ! grep -q -F "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" /jffs/scripts/post-mount; then
	      echo "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" >> /jffs/scripts/post-mount
	      autostart=1
	      echo ""
			  echo -e "${CGreen}[Modifying POST-MOUNT file]..."
			  sleep 2
			  echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Reboot Protection Enabled" >> $logfile
		    saveconfig
		    exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
	    fi

	  else
	    echo "#!/bin/sh" > /jffs/scripts/post-mount
	    echo "" >> /jffs/scripts/post-mount
	    echo "(sleep 30 && /jffs/scripts/vpnmon-r3.sh -screen) & # Added by vpnmon-r3" >> /jffs/scripts/post-mount
	    chmod 755 /jffs/scripts/post-mount
	    autostart=1
      echo ""
		  echo -e "${CGreen}[Modifying POST-MOUNT file]..."
		  sleep 2	    
		  echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Reboot Protection Enabled" >> $logfile
	  	saveconfig
	  	exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
	  fi
  
	elif [ "$autostart" == "e" ]; then
	exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
	
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
          echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: Trimmed the log file down to $logsize lines" >> $logfile
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
   } > $config
   
 	 echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: New vpnmon-r3.cfg File Saved" >> $logfile
   
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
    if [ -z "$nvramVal" ] || ! echo "$nvramVal" | grep -qE "^[0-9]$"
    then echo "0" ; else echo "$nvramVal" ; fi
    return 0
}

# -------------------------------------------------------------------------------------------------------------------------
# Initiate a VPN restart - $1 = slot number

restartvpn()
{
	
	echo -e "${CGreen}\nMessages:                           ${CClear}"
	echo ""
	printf "${CGreen}\r[Stopping VPN Client $1]"
	service stop_vpnclient$1 >/dev/null 2>&1
	sleep 5
	printf "\r                            "
	
    #Determine how many server entries are in the assigned vpn slot alternate servers file
    if [ -f /jffs/addons/vpnmon-r3.d/vr3svr$1.txt ]; then
    	servers=$(cat /jffs/addons/vpnmon-r3.d/vr3svr$1.txt | wc -l) >/dev/null 2>&1 
    	if [ -z $servers ] || [ $servers -eq 0 ]; then
  			#Restart the same server currently allocated to that vpn slot
  			printf "\r                            " 
  			printf "${CGreen}\r[Starting VPN Client $1]"
				service start_vpnclient$1 >/dev/null 2>&1
				echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted" >> $logfile
				sleep 10
  		else
    		#Pick a random server from the alternate servers file, populate in vpn client slot, and restart
    		printf "\r                            "
    		printf "${CGreen}\r[Selecting Random Entry]"
    		RANDOM=$(awk 'BEGIN {srand(); print int(32768 * rand())}')
        R_LINE=$(( RANDOM % servers + 1 ))
        RNDVPNIP=$(sed -n "${R_LINE}p" /jffs/addons/vpnmon-r3.d/vr3svr$1.txt)
        nvram set vpn_client"$1"_addr="$RNDVPNIP"
        nvram set vpn_client"$1"_desc="$RNDVPNIP added by VPNMON-R3"
        sleep 5
				#Restart the new server currently allocated to that vpn slot
				printf "\r                            "
  			printf "${CGreen}\r[Starting VPN Client $1]"
				service start_vpnclient$1 >/dev/null 2>&1
				echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted" >> $logfile
				sleep 10
    	fi
    else
    	#Restart the same server currently allocated to that vpn slot
    	printf "\r                            "
			printf "${CGreen}\r[Starting VPN Client $1]"
			service start_vpnclient$1 >/dev/null 2>&1
			echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN$1 Connection Restarted" >> $logfile
			sleep 10
    fi
	
  printf "\r                            "
	printf "${CGreen}\r[Restarting VPN Routing]"
	service restart_vpnrouting0 >/dev/null 2>&1
	echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - INFO: VPN Director Service Restarted" >> $logfile
	sleep 5
	printf "\r                            "
	trimlogs

	
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
    echo -e "${CRed} ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
	
  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]; then
    source /jffs/addons/vpnmon-r3.d/vr3clients.txt
  else
    clear
    echo -e "${CRed} ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Client Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
	slot=0
	for slot in $availableslots #loop through the 3/5 vpn slots
    do
      
    	clear
			echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v$version | $(date)                                         ${CClear}\n"
			echo -e "${CGreen}[VPN Connection Reset Commencing]"
			sleep 2

      #determine if the slot is monitored and reset it
      if [ "$((VPN$slot))" == "1" ]; then
       	restartvpn $slot
      fi
          
  done
  
  echo -e "\n${CClear}"
	exit 0

}
# -------------------------------------------------------------------------------------------------------------------------
# Find the VPN city

getvpnip()
{
	
  TUN="tun1"$1
  icanhazvpnip=$($timeoutcmd$timeoutsec nvram get vpn_client$1_rip)
  if [ -z $icanhazvpnip ]; then
		icanhazvpnip=$(curl --silent --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
  fi
	vpnip=$(printf '%03d.%03d.%03d.%03d'  ${icanhazvpnip//./ })

}

# -------------------------------------------------------------------------------------------------------------------------
# Find and remember the VPN city so it doesn't have to make successive API lookups

getvpncity()
{
	
	if [ "$1" == "1" ]; then
		lastvpnip1="$icanhazvpnip"
		if [ "$lastvpnip1" != "$oldvpnip1" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
			citychange="${CGreen}- NEW${CClear}"    
			vpncity1=$vpncity    
    fi
    vpncity=$vpncity1
		oldvpnip1=$lastvpnip1
	elif [ "$1" == "2" ]; then
		lastvpnip2="$icanhazvpnip"
		if [ "$lastvpnip2" != "$oldvpnip2" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
			citychange="${CGreen}- NEW${CClear}"        
			vpncity2=$vpncity
    fi
    vpncity=$vpncity2
		oldvpnip2=$lastvpnip2
	elif [ "$1" == "3" ]; then
		lastvpnip3="$icanhazvpnip"
		if [ "$lastvpnip3" != "$oldvpnip3" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
			citychange="${CGreen}- NEW${CClear}"     
			vpncity3=$vpncity 
    fi
    vpncity=$vpncity3
		oldvpnip3=$lastvpnip3
	elif [ "$1" == "4" ]; then
		lastvpnip4="$icanhazvpnip"
		if [ "$lastvpnip4" != "$oldvpnip4" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
			citychange="${CGreen}- NEW${CClear}" 
			vpncity4=$vpncity
    fi
    vpncity=$vpncity4
		oldvpnip4=$lastvpnip4
	elif [ "$1" == "5" ]; then
		lastvpnip5="$icanhazvpnip"
		if [ "$lastvpnip5" != "$oldvpnip5" ]; then
      vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$icanhazvpnip | jq --raw-output .city"
      vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
			citychange="${CGreen}- NEW${CClear}"      
			vpncity5=$vpncity
    fi
    vpncity=$vpncity5
		oldvpnip5=$lastvpnip5
	fi
	
}

# -------------------------------------------------------------------------------------------------------------------------
# Check health of the vpn connection using PING and CURL

checkvpn() {

  CNT=0
  TRIES=3
  TUN="tun1"$1

  while [ $CNT -lt $TRIES ]; do # Loop through number of tries
    ping -I $TUN -q -c 1 -W 2 $PINGHOST > /dev/null 2>&1 # First try pings
    RC=$?
    ICANHAZIP=$(curl --silent --retry 3 --connect-timeout 3 --max-time 6 --retry-delay 1 --retry-all-errors --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
    IC=$?
    if [ $RC -eq 0 ] && [ $IC -eq 0 ]; then  # If both ping/curl come back successful, then proceed
		  vpnhealth="${CGreen}[ OK ]${CClear}"
		  vpnindicator="${InvGreen} ${CClear}"
		  break
    else
      sleep 1 # Giving the VPN a chance to recover a certain number of times
      CNT=$((CNT+1))

      if [ $CNT -eq $TRIES ];then # But if it fails, report back that we have an issue requiring a VPN reset
        vpnhealth="${CRed}[FAIL]${CClear}"
        vpnindicator="${InvRed} ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - WARNING: VPN$1 failed to respond" >> $logfile
        if [ "$((VPN$1))" == "1" ]; then
        	resetvpn=$1
        fi
      fi
    fi
  done

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
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-setup" ] || [ "$1" == "-reset" ] || [ "$1" == "-bw" ] || [ "$1" == "-noswitch" ] || [ "$1" == "-screen" ] 
  then
    clear
  else
    clear
    echo ""
    echo " VPNMON-R3 v$Version"
    echo ""
    echo " Exiting due to invalid commandline options!"
    echo " (run 'vpnmon-r3 -h' for help)"
    echo ""
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the help option is being called
if [ "$1" == "-h" ] || [ "$1" == "-help" ]
  then
  clear
  echo ""
  echo " VPNMON-R3 v$Version Commandline Option Usage:"
  echo ""
  echo " vpnmon-r3 -h | -help"
  echo " vpnmon-r3 -setup"
  echo " vpnmon-r3 -reset"
  echo " vpnmon-r3 -bw"
  echo " vpnmon-r3 -screen"
  echo ""
  echo "  -h | -help (this output)"
  echo "  -setup (displays the setup menu)"
  echo "  -reset (resets vpn connections and exits)"
  echo "  -bw (runs vpnmon-r3 in monochrome mode)"
  echo "  -screen (runs vpnmon-r3 in screen background)"
  echo ""
  echo -e "${CClear}"
  exit 0
fi

# Check to see if a second command is being passed to remove color
if [ "$1" == "-bw" ] || [ "$2" == "-bw" ]
  then
		blackwhite
fi

# Check to see if the setup option is being called
if [ "$1" == "-setup" ]
  then
    vsetup
fi

# Check to see if the reset option is being called
if [ "$1" == "-reset" ]
  then
    vreset
fi

# Check to see if the screen option is being called and run operations normally using the screen utility
if [ "$1" == "-screen" ]
  then
    screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
    sleep 1
    ScreenSess=$(screen -ls | grep "vpnmon-r3" | awk '{print $1}' | cut -d . -f 1)
	    if [ -z $ScreenSess ]; then
	      clear
	      echo -e "${CClear} Executing ${CGreen}VPNMON-R3 v$version${CClear} using the SCREEN utility..."
	      echo ""
	      echo -e "${CClear} IMPORTANT:"
	      echo -e "${CClear} In order to keep VPNMON-R3 running in the background,"
	      echo -e "${CClear} properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
	      echo ""
	      screen -dmS "vpnmon-r3" $apppath -noswitch
	      sleep 5
	      screen -r vpnmon-r3
	      exit 0
	    else
	      clear
	      echo -e "${CClear} Connecting to existing ${CGreen}VPNMON-R3 v$Version${CClear} SCREEN session...${CClear}"
	      echo ""
	      echo -e "${CClear} IMPORTANT:${CClear}"
	      echo -e "${CClear} In order to keep VPNMON-R3 running in the background,${CClear}"
	      echo -e "${CClear} properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
	      echo ""
	      echo -e "${CClear} Switching to the SCREEN session in T-5 sec...${CClear}"
	      echo -e "${CClear}"
	      spinner 5
	    fi
	  screen -dr $ScreenSess
	  exit 0
fi

# Check to see if the noswitch  option is being called
if [ "$1" == "-noswitch" ]
  then
    clear #last switch before the main program starts
    if [ ! -f $cfgpath ] && [ ! -f "/opt/bin/timeout" ] && [ ! -f "/opt/sbin/screen" ]; then
        echo -e "${CRed} ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3 -setup' first.${CClear}"
        echo ""
        echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 is not configured. Please run the setup/configuration utility" >> $logfile
        kill 0
    fi
fi

while true; do
	
	# Grab the VPNMON-R3 config file and read it in
  if [ -f $config ]; then
    source $config
  else
    clear
    echo -e "${CRed} ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 config file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
	
  # Grab the monitored slots file and read it in
  if [ -f /jffs/addons/vpnmon-r3.d/vr3clients.txt ]; then
    source /jffs/addons/vpnmon-r3.d/vr3clients.txt
  else
    clear
    echo -e "${CRed} ERROR: VPNMON-R3 is not configured.  Please run 'vpnmon-r3.sh -setup' first."
    echo ""
    echo -e "$(date +'%b %d %Y %X') $(nvram get lan_hostname) VPNMON-R3[$$] - ERROR: VPNMON-R3 VPN Client Monitoring file not found. Please run the setup/configuration utility" >> $logfile
    echo -e "${CClear}"
    exit 0
  fi
  
  if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
    then
      timeoutcmd="timeout "
      timeoutsec="10"
    else
      timeoutcmd=""
      timeoutsec=""
  fi
	
	#Set variables
  resetvpn=0
	
	clear #display the header
	 	
 	if [ "$hideoptions" == "0" ]; then
 		resettimer=0
 		
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
 			rebootprot="${CDkGray}N${CClear}"
 		elif [ "$autostart" == "1" ]; then
 		  rebootprot="${CGreen}Y${CClear}"
 		fi
 		
 		if [ $logsize -gt 0 ]; then
 			logsizefmt=$(awk "BEGIN {printf \"%04.f\",${logsize}}")
 		else
 			logsizefmt="${CDkGray}n/a ${CClear}"
 		fi
 		
 		#display operations menu
		echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                       ${CClear}"
 		echo -e "${InvGreen} ${CClear} Reset VPN Slot ${CGreen}(1) (2) (3) (4) (5)   ${InvGreen} ${CClear} Main Setup/${CGreen}(C)${CClear}onfig Menu  ${InvGreen} ${CClear} ${CGreen}(R)${CClear}eset VPN: $schedtime"
 		echo -e "${InvGreen} ${CClear} Enable/Disable ${CGreen}(M)${CClear}onitored VPN Slots ${InvGreen} ${CClear} ${CGreen}(L)${CClear}og Viewer / Trim: ${CGreen}$logsizefmt${CClear} ${InvGreen} ${CClear} ${CGreen}(T)${CClear}imer Loop: ${CGreen}${timerloop}s${CClear}"
 		echo -e "${InvGreen} ${CClear} Update/Maintain ${CGreen}(V)${CClear}PN Server Lists   ${InvGreen} ${CClear} ${CGreen}(A)${CClear}utostart on Reboot: $rebootprot  ${InvGreen} ${CClear}"
		echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
 		echo ""
 	else
 		resettimer=0
 	fi
	
	#Display VPN client slot grid
	echo -e "${InvGreen} ${InvDkGray}${CWhite} VPNMON-R3 - v$version | ${CGreen}(S)${CWhite}how/${CGreen}(H)${CWhite}ide Operations Menu | $(date)      ${CClear}"
	if [ "$UpdateNotify" != "0" ]; then echo -e "$UpdateNotify\n"; else echo -e "${CClear}"; fi
	echo -e "  Slot | Mon |  Svrs  | Health | VPN State    | Public VPN IP   | City Exit"
	echo -e "  -----|-----|--------|--------|--------------|-----------------|-----------------------"
	
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
      	vpnip="               "
      	vpncity=""
      elif [ "$vpnstate" == "1" ]; then
      	vpnstate="Connecting  "
      	vpnhealth="${CDkGray}[n/a ]${CClear}"
      	vpnindicator="${InvYellow} ${CClear}"
      	vpnip="               "
      	vpncity=""
      elif [ "$vpnstate" == "2" ]; then
      	vpnstate="Connected   "
      	checkvpn $i
				getvpnip $i
        getvpncity $i
      else
      	vpnstate="Unknown     "
      	vpnhealth="${CDkGray}[n/a ]${CClear}"
      	vpnindicator="${InvDkGray} ${CClear}"
      	vpnip="               "
      	vpncity=""
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
          
      #print the results of all data gathered sofar
      echo -e "$vpnindicator${InvDkGray}${CWhite} VPN$i${CClear} | $monitored | $servercnt | $vpnhealth | $vpnstate | $vpnip | $vpncity $citychange"
            
      #if a vpn is monitored and disconnected, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$vpnstate" == "Disconnected" ]; then #reconnect
       	restartvpn $i
       	exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi
      
      #if a vpn is monitored and not responsive, try to restart it
      if [ "$((VPN$i))" == "1" ] && [ "$resetvpn" != "0" ]; then #reconnect
       	restartvpn $resetvpn
       	exec sh /jffs/scripts/vpnmon-r3.sh -noswitch
      fi
      
  done
	
	echo -e "  -----|-----|--------|--------|--------------|-----------------|-----------------------"
 	echo ""
 	
 	#display a standard timer
 	timer=0
  while [ $timer -ne $timerloop ]
    do
      timer=$(($timer+1))
      preparebar 46 "|"
      progressbaroverride $timer $timerloop "" "s" "Standard"
      sleep 1
      if [ "$resettimer" == "1" ]; then timer=$timerloop; fi
  done

done
echo -e "${CClear}"
exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
