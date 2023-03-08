#!/bin/env python3

'''
Quick script to extract Atomic Red Team test metadata and write out to a tab delimited file for importing to a spreadsheet program.
'''

import os
import re
import sys
import yaml

def usage():
	print('%s: <AtomicRedTeam/atomics path>' % sys.argv[0])
	sys.exit(1)
	return

def main():
	data=[]

	try:
		# path to AtomicRedTeam/atomics directory
		dirpath = sys.argv[1]
		for root, dirs, files in os.walk(dirpath, topdown=False):
			for name in files:
				if name.endswith('.yaml'):
					yamlfile = os.path.join(root, name)
					f = open(yamlfile, 'r')
					doc = yaml.load(f.read(), Loader=yaml.Loader)
					f.close()
					if 'attack_technique' not in doc:
						continue
					newdata = {'id': doc['attack_technique'], 'name': doc['display_name'], 'tests': []}
					for section in doc['atomic_tests']:
						sectiondata = {'name': section['name'], 'desc': re.sub(r'[\t\r\n]', ' ', section['description']), 'platforms': section['supported_platforms']}
						if 'executor' in section:
							if 'command' in section['executor']:
								# collapse multi-command steps to one line
								sectiondata['cmd'] = re.sub(r'[\t\r\n]', ' ; ', section['executor']['command'])
						newdata['tests'].append(sectiondata)
					data.append(newdata)
	except:
		usage()

	# Now, write out a tab delimited file.
	outfile = 'atomic-parsed.tsv'
	f = open(outfile, 'w')
	f.write('id\tid name\ttest name\ttest desc\tplatform\tcommand\n')

	for attk_item in data:
		for test_item in attk_item['tests']:
			for platform in test_item['platforms']:
				outstring = '%s\t%s\t%s\t%s\t%s\t' % (attk_item['id'], attk_item['name'], test_item['name'], test_item['desc'], platform)
				if 'cmd' in test_item:
					outstring += test_item['cmd']
				outstring += '\n'
				f.write(outstring)
	f.close()

	print('%s created.' % outfile)
	return

if __name__ == '__main__': main()
