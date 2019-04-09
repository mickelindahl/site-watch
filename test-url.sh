#!/bin/bash

SITE_URL=$1
REINSTALL=$3
PATH_SRC=$4
USER=$5
CONTAINER_1=$6
CONTAINER_2=$7

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$SITE_URL")

COUNTER_FILE=$SITE_URL.counter
INTERVAL=30 # Interval to keep on triggeiring error messages after first one has been triggred
LOG_FILE="log"

if [ $STATUS_CODE == $2 ];then

   echo "Ok $SITE_URL reponded with $2"

   if [ -f "$COUNTER_FILE" ];then

      export $(cat $COUNTER_FILE | xargs)

      echo "$(date '+%Y-%m-%d %H:%M') | SUCCESS ${SITE_URL} | Status code ${STATUS_CODE} | ${COUNT} minutes | From code $ERROR_CODE" >> $LOG_FILE

      subject="$SITE_URL recovered from $ERROR_CODE"
      body="Hi,\r\n\r\nSite $SITE_URL recovered from $ERROR_CODE.\r\n\r\n"
      body="$body$COUNT minutes since first error.\r\n\r\n"

      from="site-watch@greencargo.com"
      to="mikael.lindahl@greencargo.com, tomas.einarsson@greencargo.com"
      echo -e "Subject:${subject}\n${body}" | /sbin/sendmail -f "${from}" -t "${to}"

      rm $COUNTER_FILE

   fi
else

   if [ ! -f "$COUNTER_FILE" ];then

       touch $COUNTER_FILE
       echo "COUNT=0" > $COUNTER_FILE
       echo "ERROR_CODE=0" >> $COUNTER_FILE

   fi

   export $(cat $COUNTER_FILE | xargs)

   let MOD=COUNT%$INTERVAL

   # Update immidiatly so not next cron trigger will pick up old count 
   let COUNT=COUNT+1
   echo "COUNT=$COUNT" > $COUNTER_FILE
   echo "$(date '+%Y-%m-%d %H:%M') | ERROR ${SITE_URL} | Status code ${STATUS_CODE} | ${COUNT} minutes" >> $LOG_FILE
   echo "ERROR_CODE=$STATUS_CODE" >> $COUNTER_FILE

   if  [ $MOD == 0 ];then

      subject="$SITE_URL response with $STATUS_CODE"
      body="Hi,\r\n\r\nSite $SITE_URL respond with $STATUS_CODE.\r\n\r\n"
      body="${body}${COUNT} minutes since first error.\r\n\r\n"
      body="${body}Mod: $MOD, Interval: $INTERVAL\r\n\r\n"
      body="${body}Reinstall after one interval: $REINSTALL.\r\n\r\n"
      body="${body}Path source: $PATH_SRC.\r\n\r\n"
      body="${body}User: $USER.\r\n\r\n"
      body="${body}Please investigate.\r\n\r\n"

      if [[ $REINSTALL == 'yes' ]] && [[ $COUNT -ge $INTERVAL ]];then

          # Free memory
          echo 1 > /proc/sys/vm/drop_caches

          cd $PATH_SRC
          sudo -u $USER ./install.sh > tmp

          body="${body}Log install:\r\n\r\n"

          while IFS='' read -r line || [[ -n "$line" ]]; do
             body="${body}$line\r\n"
          done < "tmp"

          rm tmp

      fi

      if [[ $COUNT == 0 ]] && [[ -z $CONTAINER_1 ]];then

         docker logs $CONTAINER_1 --since 1440 -t > tmp

         body="${body}Log container $CONTAINER_1:\r\n\r\n"

         while IFS='' read -r line || [[ -n "$line" ]]; do
             body="${body}$line\r\n"
         done < "tmp"

         rm tmp

      fi

      if [[ $COUNT == 0 ]] && [[ -z $CONTAINER_2 ]];then

         docker logs $CONTAINER_2 --since 1440 -t > tmp

         body="${body}Log container $CONTAINER_2:\r\n\r\n"

         while IFS='' read -r line || [[ -n "$line" ]]; do
             body="${body}$line\r\n"
         done < "tmp"

         rm tmp

      fi

      from="site-watch@greencargo.com"
      to="mikael.lindahl@greencargo.com, tomas.einarsson@greencargo.com"
      echo -e "Subject:${subject}\n${body}" | /sbin/sendmail -f "${from}" -t "${to}"

   fi

fi

#/sbin/sendmail "$to" <<EOF
#subject:$subject
#from:$from
#$body
#EOF
