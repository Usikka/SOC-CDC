#!/bin/bash


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Global Variable initialisation
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

input_file=$1
normalized_file=".normalized.csv"
valid_ip=".valid_ip.csv"
invalid_ip=".invalid_ip.csv"
private_ip=".private_ip.csv"
public_ip=".public_ip.csv"
timestamp=$(date +%Y%m%d_%H%M)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Clearing output files.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

> "$normalized_file"
> "$valid_ip"
> "$invalid_ip"
> "$private_ip"
> "$public_ip"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Checking the input file
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [[ -z $input_file ]]; then							# Checking if the input file is passed as an argument
	while true; do
		read -p "Enter input file name: " input_file			# prompting for user input of file name
		if [[ -f "$input_file" && -s "$input_file" ]]; then
			break
		else
			echo "File does not exist or is empty. Try again."	# Incorrect file name, Displays all the files in the working directory
			echo "Available files in the directory:"
			ls -1
		fi
	done
fi
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# File normalization (clearing empty lines and spaces)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "Normalizing the input file......"

while IFS= read -r line								# Reading line by line without auto formatting whitespaces
do
	clean_line="$(echo "$line" | tr -d '[:space:]')"			# Trimming all white spaces, tabs, etc..
	clean_line="${clean_line%"${clean_line##*[!.]}"}"			# Removes all the trailing dots
	if [[ -z "$clean_line" ]]; then						# Skipping empty lines.
		continue
	fi

	echo "$clean_line" >> "$normalized_file"				# Outputing the clean line onto a temporary file
done < "$input_file"

echo "Input file normalized"
sleep 1
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#FUNCTIONS
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#1. Function to extract valid ips from the normalized file
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Validate() {

	local ip="$1"

	IFS='.' read -r o1 o2 o3 o4 <<<"$ip"					# Split the IP into octets

	[[ -z "$o1" || -z "$o2" || -z "$o3" || -z "$o4" ]] && return 1		# Checking to see if 4 octets are present

	[[ "$o1" == "0" ]] && return 1						# First octet cannot be zero

	for octet in "$o1" "$o2" "$o3" "$o4"; do				# Rejecting octets having leading zeroes
		[[ "$octet" =~ ^0[0-9]+$ ]] && return 1
	done

	for octet in "$o1" "$o2" "$o3" "$o4"; do				# Validating the numerical range is between 0 and 255
		[[ "$octet" =~ ^[0-9]+$ ]] || return 1
		((octet >= 0 && octet <= 255)) || return 1
	done
	return 0

}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#2. Function to extract private & public ips from the valid ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Classify() {

	local ip="$1"

	IFS='.' read -r o1 o2 o3 o4 <<<"$ip"					# Split the IP into octets

	o1=$((o1))								# Converting the octets into integers
	o2=$((o2))
	o3=$((o3))
	o4=$((o4))

										# Check private ranges
	if [[ $o1 -eq 10 ]]; then						# Check Class A (10.x.x.x)
		echo "$ip" >> "$private_ip"
	elif [[ $o1 -eq 172 && $o2 -ge 16 && $o2 -le 31 ]]; then		# Check Class B (172.16.x.x to 172.31.x.x)
		echo "$ip" >> "$private_ip"
	elif [[ $o1 -eq 192 && $o2 -eq 168 ]]; then				# Check Class C (192.168.x.x)
		echo "$ip" >> "$private_ip"					# Appends the private ip onto a temporary file
	else
		echo "$ip" >> "$public_ip"					# Appends the public ip onto a temporary file
	fi
	
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#3. Function to display and save valid ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Disp_valid() {

        less "$valid_ip"                                             		# Displays the valid ips
        read -p "Would you like to save this file (Y/N): " opt			
	if [[ $opt == "Y" || $opt == "y" ]]; then
		read -p "File Name: (leave blank to use a default name)" Valid_IP_Filename
		if [[ -z "$Valid_IP_Filename" ]]; then				# Checks for user input
			Valid_IP_Filename="Valid_IP_List_${timestamp}"		# Assigns a default file name
		fi
		cp -i "$valid_ip" "${Valid_IP_Filename//[[:space:]]/}.csv"	# Saves the valid ip file while ensuring no trailing whitespaces
		echo "File saved"
	elif [[ $opt == "N" || $opt == "n" ]]; then
		echo "File will not be saved"
	else
		echo "Invalid Option..."
		echo "File not saved"
	fi
}
#=====================================================================================================================================================



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#4. Function to display and save private ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Disp_private() {

	less "$private_ip"							# Displays the Private ips
        read -p "Would you like to save this file (Y/N): " opt
        if [[ $opt == "Y" || $opt == "y" ]]; then
                read -p "File Name: (leave blank to use a default name)" Private_IP_Filename
                if [[ -z "$Private_IP_Filename" ]]; then    	    		# Checks for user input
                        Private_IP_Filename="Private_IP_List_${timestamp}" 	# Assigns a default file name
                fi
                cp -i "$private_ip" "${Private_IP_Filename//[[:space:]]/}.csv"	# Saves the private ip file while ensuring no trailing whitespaces
                echo "File saved"
        elif [[ $opt == "N" || $opt == "n" ]]; then
                echo "File will not be saved"
        else
                echo "Invalid Option..."
                echo "File not saved"
        fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#5. Function to display public ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Disp_public() {

        less "$public_ip"							# Displays the Public ips
        read -p "Would you like to save this file (Y/N): " opt
        if [[ $opt == "Y" || $opt == "y" ]]; then
                read -p "File Name: (leave blank to use a default name)" Public_IP_Filename
                if [[ -z "$Public_IP_Filename" ]]; then 			# Checks for user input
                        Public_IP_Filename="Public_IP_List_${timestamp}"	# Assigns a default file name
                fi
                cp -i "$public_ip" "${Public_IP_Filename//[[:space:]]/}.csv"	# Saves the public ip file while ensuring no trailing whitespaces
                echo "File saved"
        elif [[ $opt == "N" || $opt == "n" ]]; then
                echo "File will not be saved"
        else
                echo "Invalid Option..."
                echo "File not saved"
        fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#6. Function to display invalid ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Disp_invalid() {

        less "$invalid_ip"							# Displays the invalid ips
        read -p "Would you like to save this file (Y/N): " opt
        if [[ $opt == "Y" || $opt == "y" ]]; then
                read -p "File Name: (leave blank to use a default name)" Invalid_IP_Filename
                if [[ -z "$Invalid_IP_Filename" ]]; then        		# Checks for user input
                        Invalid_IP_Filename="Invalid_IP_List_${timestamp}"	# Assigns a default file name
                fi
                cp -i "$invalid_ip" "${Invalid_IP_Filename//[[:space:]]/}.csv"	# Saves the invalid ip file while ensuring no trailing whitespaces
                echo "File saved"
        elif [[ $opt == "N" || $opt == "n" ]]; then
                echo "File will not be saved"
        else
                echo "Invalid Option..."
                echo "File not saved"
        fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#7. Display Menu Function
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Disp_opt() {

	while true; do
		echo ""
		echo ""
		echo "Please enter an option"
		echo "1. Display All Valid IPs"
		echo "2. Display Private IPs"
		echo "3. Display Public IPs"
		echo "4. Display Invalid IPs"
		echo "0. Go To Previous Menu"
		echo "Q. Exit"
		echo ""
		read -r DisplayOption
		case $DisplayOption in
			"1" )
				Disp_valid
				;;
			"2" )
				Disp_private
				;;
			"3" )
				Disp_public
				;;
			"4" )
				Disp_invalid
				;;
			"0" )
				break
				;;
			"Q" )
				exit 0
				;;
			"q" )
				exit 0
				;;
			* )
				echo "Invalid option..."
				echo "Exiting the program..."
				exit 1
		esac
	done
		
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#8. Function to delete valid ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Del_valid() {

	if [[ -z "$Valid_IP_Filename" ]]; then					# Checking if the variable is non-empty
		echo "No saved valid IP file name found."
		echo "Save the valid IP file first using display menu."
		return
	fi

	if [[ -e "${Valid_IP_Filename}.csv" ]]; then				# Checking if the file exist
		rm -i "${Valid_IP_Filename}.csv"
	else
		echo "Valid IP List does not exist"
	fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#9. Function to delete private ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Del_private() {

        if [[ -z "$Private_IP_Filename" ]]; then
                echo "No saved Private IP file name found."
                echo "Save the Private IP file first using display menu."
                return
        fi

        if [[ -e "${Private_IP_Filename}.csv" ]]; then
                rm -i "${Private_IP_Filename}.csv"
        else
                echo "Private IP List does not exist"
        fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#10. Function to delete public ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Del_public() {

        if [[ -z "$Public_IP_Filename" ]]; then
                echo "No saved Public IP file name found."
                echo "Save the Public IP file first using display menu."
                return
        fi

        if [[ -e "${Public_IP_Filename}.csv" ]]; then
                rm -i "${Public_IP_Filename}.csv"
        else
                echo "Public IP List does not exist"
        fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#11. Function to delete invalid ips
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Del_invalid() {

        if [[ -z "$Invalid_IP_Filename" ]]; then
                echo "No saved Invalid IP file name found."
                echo "Save the Invalid IP file first using display menu."
                return
        fi

        if [[ -e "${Invalid_IP_Filename}.csv" ]]; then
                rm -i "${Invalid_IP_Filename}.csv"
        else
                echo "Invalid IP List does not exist"
        fi
}
#=====================================================================================================================================================


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#12. Delete Menu Function
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Del_opt() {

        while true; do
		echo ""
		echo ""
                echo "Please enter an option: "
                echo "1. Delete All Valid IPs"
                echo "2. Delete Private IPs"
                echo "3. Delete Public IPs"
                echo "4. Delete Invalid IPs"
                echo "0. Go To Previous Menu"
                echo "Q. Exit"
		echo ""
                read -r DeleteOption
                case $DeleteOption in
                        "1" )
                                Del_valid
                                ;;
                        "2" )
                                Del_private
                                ;;
                        "3" )
                                Del_public
                                ;;
                        "4" )
                                Del_invalid
                                ;;
                        "0" )
                                break
                                ;;
                        "Q" )
                                exit 0
                                ;;
                        "q" )
				exit 0
                                ;;
                        * )
                                echo "Invalid option..."
                                echo "Exiting the program..."
                                exit 1
                esac
        done

}
#=====================================================================================================================================================


#=====================================================================================================================================================
# MAIN
#=====================================================================================================================================================

while IFS= read -r ip; do						
	if Validate "$ip" > /dev/null; then					# Validating the IP
		echo "$ip" >> "$valid_ip"
		Classify "$ip"							# Classifying valid IPs
	else
		echo "$ip" >> "$invalid_ip"
	fi
done < "$normalized_file"

if [[ ! -s "$valid_ip" ]]; then							# Checking if valid ips are present
	echo "No valid ip found from the list"
	exit 1
fi

while true; do
	echo ""
	echo ""
	echo "Please enter an option"						# Main menu
	echo "1. Display Options"
	echo "2. Delete Options"
	echo "Q. Exit"
	echo ""
	read MO
	case $MO in
		"1" )
			Disp_opt
			;;
		"2" )
			Del_opt
			;;
		"Q")
			exit 0
			;;
		"q" )
			exit 0
			;;
		* )
			echo "Invalid option..."
			echo "Exiting the program..."
			exit 1
	esac
done
