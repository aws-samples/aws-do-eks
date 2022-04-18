# This script is very specific to the ImageNet dataset.
# It rearranges the data in val directory so that it can be read by
# PyTorch ImageFolder class.

import os
import glob
from bs4 import BeautifulSoup

def get_tags_from_xml(file_name):
    with open(file_name, "r") as f:
        contents = BeautifulSoup(f.read(), 'xml')

    filename = contents.find('filename').get_text()
    label = contents.find('name').get_text()

    return filename+'.JPEG', label

def main():
    xml_file_list = glob.glob('/fsx-shared/ILSVRC/Annotations/CLS-LOC/val/*.xml')

    data = {}
    for file in xml_file_list:
        filename, label = get_tags_from_xml(file)
        data[filename] = label

    labels = set(data.values())

    root_dir = '/fsx-shared/ILSVRC/Data/CLS-LOC/val'
    for label in labels:
        os.mkdir(root_dir + '/' + label)

    for file in data:
        src = root_dir + '/' + file
        dst = root_dir + '/' + data[file] + '/' + file
        os.replace(src, dst)

if __name__ == "__main__":
    main()
