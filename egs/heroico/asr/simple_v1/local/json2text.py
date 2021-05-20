import json

input_file=open('exp/data/supervisions_train.json', 'r')

json_decode=json.load(input_file)
for item in json_decode:
    t = item.get('text')
    print(t)
