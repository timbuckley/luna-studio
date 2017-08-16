#!/usr/bin/env python3

from . import atom_prepare as ap
import os
import distutils
from glob import glob
import shutil
import subprocess
from . import system as system


resources_dir = ap.prep_path('../resources')
supervisor_dir = ap.prep_path('../supervisor')
windows_dir = ap.prep_path('../windows')
env_dir = ap.prep_path('../env')


def copy_configs(supervisor,env, windows):
    config_path = ap.prep_path('../dist/config/')
    supervisor_path = config_path + '/supervisor'
    env_path = config_path + '/env'
    windows_path = config_path + '/windows'
    distutils.dir_util.copy_tree(env, env_path)

    if system.system == system.systems.WINDOWS:
        distutils.dir_util.copy_tree(windows, windows_path)
    elif system.system == system.systems.LINUX:
        distutils.dir_util.copy_tree(supervisor, supervisor_path)
    elif system.system == system.systems.DARWIN:
        distutils.dir_util.copy_tree(supervisor, supervisor_path)
    else: print("unknown system")

def copy_resources(resources):
    resources_path=ap.prep_path('../dist/bin/public/luna-studio/resources')
    distutils.dir_util.copy_tree(resources, resources_path)

def link_resources ():
    os.chdir(ap.prep_path('../dist/bin'))
    os.makedirs('main/resources', exist_ok=True)
    for src_path2 in glob('public/luna-studio/resources/*'):
        dst_path = os.path.join('main/resources', os.path.basename(src_path2))
        if os.path.isfile(dst_path):
            if os.path.isfile(src_path2):
                os.remove(dst_path)
                os.symlink(os.path.relpath(src_path2,'main/resources/'),os.path.join('main/resources', os.path.basename(src_path2)))
            else: return ()
        else:
            if os.path.isfile(src_path2):
                os.symlink(os.path.relpath(src_path2,'main/resources/'),os.path.join('main/resources', os.path.basename(src_path2)))
            else: return ()

def copy_atom_configs ():
    dst_path = ap.prep_path('../dist/user-config/atom')
    for config in ('../config/config.cson', '../config/keymap.cson', '../config/snippets.cson', '../config/styles.cson'):
        shutil.copy(ap.prep_path(config), dst_path)

def run():
    copy_configs(supervisor_dir,env_dir, windows_dir)
    copy_resources(resources_dir)
    link_resources ()
    copy_atom_configs ()

if __name__ == '__main__':
    run()
