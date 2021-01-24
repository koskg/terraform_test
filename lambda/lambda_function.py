import boto3
import psycopg2 

def lambda_handler(event, context):

    conn = psycopg2.connect(dbname='mydb', user='admintest', password='admintest', host='terraform-20210123184841680400000001.ccozp814aeks.eu-central-1.rds.amazonaws.com')
    cursor = conn.cursor()
    cursor.execute('SELECT count(*) FROM numbers')
    count =str(cursor.fetchone()[0] - 10)
    cursor.execute('SELECT * FROM numbers LIMIT 10 OFFSET  %s', (count))
    records = cursor.fetchall()
    cursor.close()
    conn.close()

#===============================================
    s = "\n"
    s = s.join([str(qwe[0]) for qwe in records])
    s3 = boto3.resource('s3')
    object = s3.Object('my-test-s3-bucket-for-numbers-51243', 'my_numbers.txt')
    object.put(Body=s)
    print (s)
    # return (s)