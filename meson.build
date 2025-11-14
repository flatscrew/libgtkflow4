#********************************************************************
# Copyright 2014-2022 Daniel 'grindhold' Brendle
#
# This file is part of libgtkflow.
#
# libgtkflow is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later
# version.
#
# libgtkflow is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with libgtkflow.
# If not, see http://www.gnu.org/licenses/.
#********************************************************************

project ('gtkflow', 'vala', 'c', meson_version: '>=0.47')
pkgconfig = import('pkgconfig')

gflow_dep_api = '1.0'


glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gflow = dependency('gflow-' + gflow_dep_api)
math = meson.get_compiler('c').find_library('m', required: true)
gtk4 = dependency('gtk4')

g_ir_compiler = find_program('g-ir-compiler')

src = files([
    'dock.vala',
    'minimap.vala',
    'node.vala',
    'nodeview.vala',
    'init.vala'
])

fs = import('fs')

version_file = join_paths(meson.project_source_root(), 'VERSION')
gtkflow4_api = fs.read(version_file).strip()

gtkflow4_deps = [glib, gobject, gflow, gtk4, math]
gtkflow4_links = []
gtkflow4_include_dirs = []


gtkflow4 = library('gtkflow4-' + gtkflow4_api,
                  src,
                  dependencies: gtkflow4_deps,
                  link_with: gtkflow4_links,
                  include_directories: gtkflow4_include_dirs,
                  vala_gir: 'GtkFlow4-' + gtkflow4_api + '.gir',
                  install: true)

gtkflow4_inc = include_directories('.')

gtkflow4_typelib_cmd = [g_ir_compiler, '--output', '@OUTPUT@', meson.current_build_dir() + '/GtkFlow4-' + gtkflow4_api + '.gir',
                       '--shared-library', get_option('prefix') + '/' + get_option('libdir') + '/libgtkflow4-'+ gtkflow4_api +'.so']
custom_target('gtkflow4-typelib',
              command: gtkflow4_typelib_cmd,
              output: 'GtkFlow4-' + gtkflow4_api + '.typelib',
              depends: gtkflow4,
              install: true,
              install_dir: get_option('libdir') + '/girepository-1.0')

girfilename4 = meson.current_build_dir() + '/GtkFlow4-' + gtkflow4_api + '.gir'
run_command('touch', girfilename4)
install_data(sources: girfilename4,
             install_dir: get_option('datadir') + '/gir-1.0')

vapifilename4 = meson.current_build_dir() + '/gtkflow4-' + gtkflow4_api + '.vapi'
run_command('touch', vapifilename4)
install_data(sources: vapifilename4,
             install_dir: get_option('datadir') + '/vala/vapi')

headerfilename4 = meson.current_build_dir () + '/gtkflow4-' + gtkflow4_api + '.h'
run_command('touch', headerfilename4)
install_headers(headerfilename4,
                subdir: 'gtkflow4-' + gtkflow4_api)
install_data(sources: [meson.current_source_dir() + '/gtkflow4-' + gtkflow4_api + '.deps'],
             install_dir: get_option('datadir') + '/vala/vapi')

pkgconfig.generate(libraries: [gtkflow4],
                   subdirs: 'gtkflow4-' + gtkflow4_api,
                   version: gtkflow4_api,
                   name: 'gtkflow4',
                   filebase: 'gtkflow4-' + gtkflow4_api,
                   requires: ['glib-2.0', 'gobject-2.0', 'gflow-' + gflow_dep_api],
                   description: 'A library to create flowgraphs in GTK+')

if get_option('enable_valadoc')
    valadoc = find_program('valadoc')
    gtkflow4_docs = custom_target('gtkflow4_apidocs',
                                 depends: gtkflow4,
                                 input: src,
                                 install: true,
                                 # FIXME: Installing to tmp, so the target will be built
                                 #        the problem is we cannot access a subfolder of the
                                 #        buildtarget via the output parameter.
                                 #        Find a nicer solution
                                 install_dir: '/tmp',
                                 command: [valadoc, '-o', meson.current_build_dir() + '/gtkflow4-' + gtkflow4_api, '--doclet', 'devhelp', '@INPUT@',
                                 '--pkg', 'gtk4', '--vapidir=' + meson.current_build_dir() + '/../libgflow/', '--pkg', 'gflow-' + gflow_dep_api,
                                 '--force'],
                                 output: 'gtkflow4-'+ gtkflow4_api)
    install_subdir(meson.current_build_dir() + '/gtkflow4-' + gtkflow4_api + '/gtkflow4-' + gtkflow4_api,
                   install_dir: get_option('datadir') + '/devhelp/books',
                   )
endif
