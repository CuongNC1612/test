#!/bin/bash
CUR_DIR=`dirname ${BASH_SOURCE[0]}`
DATE=`date +%Y-%m-%d`
DATE_H=`date -d '1 hour ago' +%Y-%m-%d-%H`
#--
YESTERDAY=`date --date="1 days ago" +%Y-%m-%d`
LOG_PATH=/opt/tomcat_cas/logs
#--
LOG_FILE=/opt/tomcat/logs/cas.log.$YESTERDAY
LOG_F=/tmp/.log_cas_f.txt
LOG_S=/tmp/.log_cas_s.txt
LOG_ST=/tmp/.log_cas_st.txt
LOG_T=/tmp/.log_cas_t.txt
IP_LIST=/tmp/.ip_login_m.txt
LIST_USER=/tmp/.login_user.txt
RESULT_CHECK=$CUR_DIR/$YESTERDAY/check_ip_result.txt
#RESULT_CHECKT=/tmp/.result_checkt.txt
MAIL_TMP=$CUR_DIR/mail_tmp.txt
mkdir -p $CUR_DIR/$YESTERDAY/
CAS_SERVER1=1.2.3.5
CAS_SERVER2=1.2.3.6
# remove tmp file
rm -f $LOG_F $LOG_S $LOG_T $IP_LIST $RESULT_CHECK $LIST_USER $LOG_ST
# get log from cas server to check server
ssh $CAS_SERVER1 "grep -B 4 -A 3 'ACTION: AUTHENTICATION' $LOG_FILE | grep -v 'APPLICATION\|WHAT\|WHEN' | grep -v '\-\-\|============================================================='" > $LOG_F
ssh $CAS_SERVER2 "grep -B 4 -A 3 'ACTION: AUTHENTICATION' $LOG_FILE | grep -v 'APPLICATION\|WHAT\|WHEN' | grep -v '\-\-\|============================================================='" >> $LOG_F
# cut and rearrange cas logs
while read line1 ; do
        read line2
        read line3
        read line4
                IP=`echo "$line4" | awk '{print $4}'`
                TIME=`echo  "$line1" | awk -F ',' '{print $1}'`
                USER=`echo "$line2" | awk -F"[|]|:" '{print $3}'`
                ACTION=`echo "$line3" | awk '{print $2}'`
        echo "$IP, $USER, $ACTION, $TIME" >> $LOG_ST
done < $LOG_F
cat $LOG_ST | grep -v "10.8.*\|10.9.*\|117.55.222.56" | awk -F"TM" '{lines[$1]=$2} END {for (i in lines) {print i lines[i]}}' > $LOG_S
# get list IP duplicate
cat $LOG_S | awk '{print$1}' | sort | uniq -c | awk '$1 > 1  {print $2}'  > $IP_LIST
# get ip and user duplicate
for x in `cat $IP_LIST`
do
     grep $x $LOG_S > /tmp/.tmp_f
     TMP=`awk -F',' '{print $2}' /tmp/.tmp_f | sort | uniq -c | wc -l`
     if [ $TMP -gt 1 ]
         then
             grep $x $LOG_S >> $RESULT_CHECK
         fi
done
#reove special character
sed -i -e 's/\]//g' $RESULT_CHECK
#check lock user
LOG_F_LOCK=/tmp/.log_f_lock.txt
RESULT_CHECK_LOCK=/tmp/.result_lock.txt
#remove tmp file
rm -f $LOG_F_LOCK $RESULT_CHECK_LOCK
# get lock logs from cas server
ssh $CAS_SERVER1 "grep 'LOCKOUT' $LOG_FILE" > $LOG_F_LOCK
ssh $CAS_SERVER2 "grep 'LOCKOUT' $LOG_FILE" >> $LOG_F_LOCK
# remake logs file
while read line; do
IP=`echo $line | awk '{print $12}'`
USER=`echo $line | awk '{print $10}'`
TIME=`echo $line | awk  -F',' '{print $1}'`
echo "$IP, $USER CURRENT IS LOCKED, $TIME"  >> $RESULT_CHECK_LOCK
done <  $LOG_F_LOCK
cat $RESULT_CHECK_LOCK | awk -F"TM" '{lines[$1]=$2} END {for (i in lines) {print i lines[i]}}' >> $RESULT_CHECK
# send mail if have many account login from one IP or lock user
if [ -s $RESULT_CHECK ]
then
cd $CUR_DIR/$YESTERDAY
zip -P abc123adf result_check_ip_warn$YESTERDAY.zip check_ip_result.txt
#cat ../mail_tmp.txt  | mailx -a "result_check_ip_warn$YESTERDAY.zip" -s " [$YESTERDAY][PROD][REPORT]Check account login via duplicate IP address" -S smtp=1.2.3.4 -S smtp-auth=login -S smtp-auth-user=n<email>@uat-jp-st.localdomain -S smtp-auth-password=<password> -S from="noreply@uat-jp-st.localdomain" abc@123.com
fi
