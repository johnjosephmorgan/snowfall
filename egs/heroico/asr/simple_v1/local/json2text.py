import json
input_file=open('exp/data/supervisions_train.json', 'r')
output_file=open('text.json', 'w')
json_decode=json.load(input_file)
for item in json_decode:
    my_dict={}
    my_dict['text']=item.get('labels').get('text'))
    print my_dict
back_json=json.dumps(my_dict, output_file)
output_file.write(back_json)
output_file.close() 
