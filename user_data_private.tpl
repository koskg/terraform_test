#!/bin/bash
sudo amazon-linux-extras install nginx1 -y 
sudo service nginx start
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo unzip awscliv2.zip
sudo ./aws/install
touch /home/ec2-user/task.sh
cat > /home/ec2-user/task.sh  <<EOF
#!/bin/bash
export AWS_ACCESS_KEY_ID=******
export AWS_SECRET_ACCESS_KEY=********
aws s3 cp s3://my-test-s3-bucket-for-numbers-51243/my_numbers.txt my_numbers.txt
readarray arr < my_numbers.txt
for n in \${arr[@]}
do
   out=\$(( \$n % 2 ))
   if [ \$out -eq 0 ]
   then
   arr3+=(\$n)
   fi
done
MY_SORT_ARRAY_NUBERS=(\$(echo \${arr3[*]}| tr " " "\\n" | sort -n))
INDEX_HTML_PATH=/usr/share/nginx/html/index.html
echo \${MY_SORT_ARRAY_NUBERS[@]} > \${INDEX_HTML_PATH}
EOF
sudo crontab <<EOF
* * * * * bash /home/ec2-user/task.sh
EOF
