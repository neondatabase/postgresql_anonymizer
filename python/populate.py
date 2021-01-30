#!/usr/bin/python3

import sys
import csv
import argparse
from faker import Faker


    

# FIXME: split the table in 5 : address + city + region + country + zipcode
def city(r):
    return []

def email(r):
    return [ [  oid, f.unique.email() ] for oid in range(r) ]

def company(r):
    return [ [  oid, f.unique.company() ] for oid in range(r) ]

def first_name(r):
    return [  [  oid, f.unique.first_name() ] for oid in range(r)]
    
def iban(r):
    return [ [  oid, f.unique.iban() ] for oid in range(r) ]

def last_name(r):
    return [  [  oid, f.unique.last_name() ] for oid in range(r)]

# FIXME: what's the size of the lorem ipsum column ?
def lorem_ipsum(r):
    return [  [  oid, f.unique.paragraph(nb_sentences=10) ] for oid in range(r)]
    
def siret(r):
    french_faker=Faker('fr_FR')
    if seed: 
        french_faker.seed(seed)  
    return [ [  oid, french_faker.unique.siret() ] for oid in range(r)]

# Input
parser = argparse.ArgumentParser()
parser.add_argument('--table', help='', required=True)
parser.add_argument('--locale', help='')
parser.add_argument('--lines', help='', type=int, default=1000)
parser.add_argument('--seed', help='')
args = parser.parse_args()

# Generator
f = Faker(args.locale)
if args.seed: 
    Faker.seed(args.seed)
    
for row in eval(args.table)(args.lines):
     csv.writer(sys.stdout,delimiter='\t').writerow(row)