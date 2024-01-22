import json
import pandas as pd
import boto3


def lambda_handler(event, context):

	print(event["s3bucket"])
	BUCKET_NAME = event["s3bucket"]
	print(BUCKET_NAME)
	
	s3_client = boto3.client('s3')
	s3 = boto3.resource('s3')
	bucketObj = s3.Bucket(BUCKET_NAME)
	outputKey = 'output.csv'
	outputCombinedKey = 'outputCombined.csv'

	keys = [item for item in bucketObj.objects.filter()] # get them all
	print(keys)
	for KEY in keys: 
		try:
			print(KEY.key)
			local_file_name = '/tmp/'+KEY.key
			s3.Bucket(BUCKET_NAME).download_file(KEY.key, local_file_name)
		except botocore.exceptions.ClientError as e:
			if e.response['Error']['Code'] == "404":
				continue
			else:
				raise
	
	#calculate output through panda concatenate 
	appended_data = []
	for KEY in keys:
		try:
			data = pd.read_csv('/tmp/'+KEY.key)
		
		except:
			print('Note: filename.csv was empty. Skipping.')
			continue
			
		#append the data read from the key if non empty error
		appended_data.append(data)
	
	outputCombined = pd.concat(appended_data,axis=1)
    
	#export to csv
	print(outputCombined)
	outputCombined.to_csv("/tmp/outputCombined.csv", index=False, encoding='utf-8-sig')
	
	bucketObj.upload_file('/tmp/outputCombined.csv', outputKey)

	bucket_location = boto3.client('s3').get_bucket_location(Bucket=BUCKET_NAME)
	object_url = "https://s3-{0}.amazonaws.com/{1}/{2}".format(
    bucket_location['LocationConstraint'],
    BUCKET_NAME,
    outputKey)

	return object_url