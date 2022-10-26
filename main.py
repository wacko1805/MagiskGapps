import json
import shutil
import zipfile,fnmatch,os
import pysftp
from stat import S_IWRITE, S_IWUSR

with open('module-info.json') as f:
    contents = json.load(f)
id = contents['result']['id']
name = contents['result']['name']
version = contents['result']['version']
versionCode = contents['result']['versionCode']
author = contents['result']['author']
description = contents['result']['description']
SF_folder = contents['result']['SF_folder']
SF_version = contents['result']['SF_version']
SF_user = contents['result']['SF_user']
SF_pass = contents['result']['SF_pass']

#Create module.prop

with open('template/module.prop', 'w') as f:
    f.write('id=' + id +"\n" + 'name=' + name +"\n" + 'version=' + version +"\n" + 'versionCode=' + versionCode +"\n" + 'author=' + author +"\n" + 'description=' + description)
#unzip and move AppSet files
with zipfile.ZipFile("gapps.zip", 'r') as zip_ref:
    zip_ref.extractall("gapps")
os.mkdir("AppSet")

rootPath = r"gapps/AppSet"
pattern = '*.zip'
for root, dirs, files in os.walk(rootPath):
    for filename in fnmatch.filter(files, pattern):
        print("Moving"+os.path.join(root, filename))
        zipfile.ZipFile(os.path.join(root, filename)).extractall(os.path.join("appset/"))

        os.remove("appset/installer.sh")
os.remove("appset/uninstaller.sh")
print("Moving files")

#Renames Files from ___ to /
path =  "appset"
os.chmod("C:/Users/jackc/Documents/MAGISKGAPPS/appset/", 0o777)
filenames = os.listdir(path)
for filename in filenames:
    os.renames("C:/Users/jackc/Documents/MAGISKGAPPS/appset/" + filename, "C:/Users/jackc/Documents/MAGISKGAPPS/appset" + filename.replace("___", "/"));
    print("Renaming all"+filename)
#combinds everything
    source_folder = r"template"
destination_folder = r"builds"

shutil.copytree(source_folder, destination_folder)

source_folder = r"appset"
destination_folder = r"builds/system"

shutil.copytree(source_folder, destination_folder)
print("Building Module")



shutil.make_archive("releases/MagiskGApps-"+ version, 'zip', "builds")
print("Building Zip and archiving")
os.chmod("gapps", 0o777)
os.chmod("builds", 0o777)
os.chmod("AppSet", 0o777)

shutil.rmtree("gapps", ignore_errors=True)
shutil.rmtree("builds", ignore_errors=True)
os.remove("template/module.prop")

os.remove("gapps.zip")

shutil.rmtree("AppSet", ignore_errors=True)

#Upload
srv = pysftp.Connection(host="frs.sourceforge.net", username=SF_user,
password=SF_pass)
print("Uploading to SourceForge")

with srv.cd('/home/frs/project/magiskgapps/'+SF_folder+SF_version): #chdir to public
    srv.put('releases/MagiskGApps-'+ version +'.zip') #upload file to nodejs/

# Closes the connection
srv.close()
