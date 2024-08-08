#!/bin/bash

# BARDOT Chloé / JEAN-FRANCOIS Océane / PROMIS Caroline
# TD Noté
# Document management

export PAGER
set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.
# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# If there is no argument, we exit the script with an error message.
if [[ $# -lt 1 ]]; then 
	echo "[ERROR] one command is expected." >&2
	echo -e "Usage: ./pret.sh init # Initialize an empty data store\n./pret.sh add CODE DESCRIPTION # Add a new article identified by CODE with the descriptio.\n./pret.sh lend CODE WHO # Lend the article CODE to WHO\n./pret.sh retrieve CODE # Retrieve the article CODE\n./pret.sh list items|lends # List all the items or only the lends items" >&2
	exit 1
fi


DATA_FILE="pret.json"

# This fonction generates a pret.json database with two empty "item" and "lent" tables. 
function init()
{
    # If the ".json" file already exists, the user is asked if they want to keep it or create another one.
    if [[ -f $DATA_FILE ]]; 
    then
	echo "Data already exist. Are you sure to want to delete it? (y/n)"
	read -r answer
	# {answer,,} allows the variable to be case-insensitive.
        if [[ ${answer,,} != "y" ]]; 
        then 
	    exit 1
        fi
    fi
    # Cette commande crée le fichier JQ avec les deux taleaux item et lent
    jq -n '{ "item": [], "lent": [] }' > "$DATA_FILE"
}

# This function allows you to add a document to the database.
# It takes as parameters the name of the document you want to add and its description.
function add() {
   # If there are less than two parameters, an error message is displayed and we exit the script.
   if [[ $# -lt 2 ]]; then 
	echo "[ERROR] Two params expected." >&2
	echo -e "Usage: ./pret.sh add CODE DESCRIPTION # Add a new article identified by CODE with the description." >&2
	exit 1
  fi

   CODE="$1"
   DESCRIPTION="$2"

   # If a name already exists, an error message is displayed and we exit the script.
   if jq -e --arg code "$CODE" '.item[] | select(.code == $code)' "$DATA_FILE" > /dev/null; 
   then
      echo "[ERROR] $CODE already exists and cannot be added" >&2
      exit 1
   fi

   # Now that the parameters are correct, we add the document to the database.
   # If the jq command is successful, the temporary file is renamed to replace the original data file.
   jq --arg code "$CODE" --arg description "$DESCRIPTION" '.item += [{"code": $code, "description": $description}]' "$DATA_FILE" > "$DATA_FILE".tmp && mv "$DATA_FILE".tmp "$DATA_FILE"
}

# This function allows you to save lent documents.
# It takes two parameters which are the name of the person who borrows and the name of the document borrowed.
function lend() {
   if [[ $# -lt 2 ]]; then 
	echo "[ERROR] Two params expected." >&2
	echo -e "Usage: ./pret.sh lend CODE WHO # Lend the article CODE to WHO" >&2
	exit 1
  fi

   WHAT="$1"
   WHO="$2"
   WHEN=$(date +"%d/%m/%Y")

   # If this document is in the database and it is already lent, we display an error message and we exit the script.
   if jq -e --arg code "$WHAT" '.item[] | select(.code == $code)' "$DATA_FILE" > /dev/null; 
   then
       if jq -e --arg code "$WHAT" '.lent[] | select(.what == $code)' "$DATA_FILE" > /dev/null;
       then
           echo "[ERROR] $WHAT is already lent " >&2
           exit 1
       fi
       # If this document is in the database and it is not lent, we add it to “lent documents”.
       jq --arg what "$WHAT" --arg who "$WHO" --arg when "$WHEN" '.lent += [{"when": $when, "who": $who, "what": $what}]' "$DATA_FILE" > "$DATA_FILE".tmp && mv "$DATA_FILE".tmp "$DATA_FILE"
   # If this document is not present in the database, we exit the script with an error message.
   else
       echo "[ERROR] $WHAT doesn't exist in items " >&2
       exit 1
   fi


}

# This function allows you to return documents that have been lent.
# It takes the name of the document as a parameter.
function retrieve() {
    if [[ $# -lt 1 ]]; then 
    	echo "[ERROR] One params expected." >&2
    	echo -e "Usage: ./pret.sh retrieve CODE # Retrieve the article CODE" >&2
    	exit 1
    fi
    
   ARTICLE="$1"

   # If the document is in the list of lent items and recorded in the database then it is removed from the list of lent items.
   if jq -e --arg article "$ARTICLE" '.lent[] | select(.what == $article)' "$DATA_FILE" > /dev/null; 
   then
       if jq -e --arg code "$ARTICLE" '.item[] | select(.code == $code)' "$DATA_FILE" > /dev/null; 
       then
           jq --arg article "$ARTICLE" 'del(.lent[] | select(.what == $article))' "$DATA_FILE" > "$DATA_FILE".tmp && mv "$DATA_FILE".tmp "$DATA_FILE"
       # If the document is not saved in the database, we exit the script with an error message.
       else
           echo "[ERROR] $ARTICLE doesn't exist in items " >&2
           exit 1
       fi
   # If the document is not lent, we exit the script with an error message.
   else
       echo "[ERROR] $ARTICLE  isn't lent " >&2
       exit 1
   fi
}

# This function allows you to list the documents that are in the list of lent or in the database.
# It takes as a parameter the name of the list you want to display.
function list(){
   if [[ $# -lt 1 ]]; then 
    	echo "[ERROR] One params expected." >&2
    	echo -e "Usage: ./pret.sh list items|lends # List all the items or only the lends items" >&2
    	exit 1
    fi
   TITLE="$1"
   PRINT="print.txt"

   # 
   if [[ -f $PRINT ]]; 
   then 
       rm $PRINT
   fi
   touch $PRINT

   # If the user entered the "item" parameter, the list of library documents is displayed.
   if test "$TITLE" = "item"
   then
      # Fills all the lines of the "item" table in the format "code: code of the document / description: description of the document"
      item=$(jq --compact-output -r '.item[] | "Code : \"\(.code)\" / Description : \"\(.description)\""' "$DATA_FILE")
      # We browse the existing items in the "item" table and write them in the print.txt file.
      for i in "${item[@]}"
      do
         echo "$i" >> "$PRINT"
      done
   # If the user entered the "lent" parameter, the list of lent documents is displayed.
   elif test "$TITLE" = "lent"
   then
     lent=$(jq --compact-output -r '.lent[] | "Code : \"\(.what)\" / To \(.who) / \(.when)"' "$DATA_FILE")
      for i in "${lent[@]}"
      do
         echo "$i" >> "$PRINT"
      done
   # If the parameter entered by the user is different from "item" or "lent", we exit the script with an error message.
   else
         echo "[ERROR] $TITLE doesn't correspond to 'item' nor 'lent' " >&2 
         exit 1
   fi

   # Definition of the pager according to the user's request and a default pager otherwise.
   if [ -z ${PAGER+x} ]
   then
       echo "You don't add PAGER by default, to use a PAGER select (Type 1 for less, Any other Number for more)"
       read -r CHOOSED
       if [ "$CHOOSED" -eq 1 ]
       then
           CHOOSED="less"
       else
           CHOOSED="more"
       fi
   fi

   # If the "print.txt" file exists, its content is displayed with the defined pager.
   if [[ -f $PRINT ]]; 
   then
       $CHOOSED $PRINT
       rm $PRINT
   fi
}


COMMAND="$1"
shift

# Depending on the user's choice, the corresponding function is launched.
case "${COMMAND,,}" in 
# Initialisation function.
  init)
     init 
     ;;
# Adding function.
  add)
     add "$@"
     ;;
# Lending function.
  lend)
     lend "$@"
     ;;
# retrieving function.
  retrieve) 
     retrieve "$@"
     ;;
# List function.
  list)
     list "$@"
     ;;
  # If the parameter entered by the user is not correct, we exit the script with an error message.
  *)
    echo "[ERREUR] Unknown command: $COMMAND" >&2; exit 1
     ;;
esac
