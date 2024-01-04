// Copyright 2023 remittor <remittor@gmail.com>
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT

import { open, stat, glob, lsdir, unlink, basename } from 'fs';
//import { revision as luciversion, branch as luciname } from 'luci.version';

let cm_data_fn = '/usr/share/cozymenu/cozymenu.json';
let cm_data = "_empty_";

function syslog2(prio, msg) {
	warn(sprintf("[%s] %s\n", prio, msg));
}

function dump2file(fn, data) {
	let fd = open(fn, 'w', 0600);
	fd.write(data);
	fd.close();
}

function read_jsonfile(path, defval) {
	let rv;
	try {
		rv = json(open(path, "r"));
	}
	catch (e) {
		rv = defval;
	}
	return rv;
}

function cozymenu_hook(menu) {
	//dump2file("/tmp/menu1.json", menu);
	try {
		if (!('admin' in menu.children)) {
			return menu
		}
		if (!('children' in menu.children.admin)) {
			return menu
		}
	}
	catch (e) {
		return menu;
	}
	//syslog2("info", "cozy_menu: 001");
	
	if (cm_data == "_empty_") {
		cm_data = read_jsonfile(cm_data_fn, null);
	}
	if (type(cm_data) != 'object') {
		return menu;
	}
	
	for (let nm_name, nm_v in cm_data) {
		//syslog2("info", sprintf("%s = '%s'", nm_name, nm_v));
		let nm_title = nm_v.title;
		let nm_order = nm_v.order;
		let nm_items = nm_v.items;
		//syslog2("info", sprintf("cozy_menu: first menu = '%s' '%s' %d", nm_name, nm_title, nm_order));
		
		let nm = menu.children.admin.children[nm_name];
		if (nm != null) {
			if (nm.action.type != 'firstchild') {
				syslog2("error", sprintf("cozy_menu: ERROR: incorrect '%s' menu type!", nm_name));
				return menu;
			}
			//syslog2("info", sprintf("cozy_menu: '%s' menu already exist!", nm_name));
			nm.satisfied = true;
			nm.title = nm_title;
			nm.order = nm_order;
			nm.action.recurse = true;
		} else {
			//syslog2("error", "cozy_menu: NAS menu NOT founded!");
			nm = {
				satisfied: true,
				title: nm_title,
				order: nm_order,
				action: {
					type: 'firstchild',
					recurse: true
				},
				children: {}
			};
		}		
		for (let order, v in nm_items) {
			let k = v[1];
			//syslog2("info", sprintf("cozy_menu: %d = %s", order, k));
			//syslog2("info", sprintf("    '%s'", nm.children[k]));
			if (k in nm.children) {
				//submenu already exist. Skip
				nm.children[k].order = order + 1;
			} else if (length(v) > 1) {
				let k1 = v[0];
				let k2 = v[1];
				if (k1 in menu.children.admin.children && menu.children.admin.children[k1]) {
					if (k2 in menu.children.admin.children[k1].children) {
						nm.children[k] = menu.children.admin.children[k1].children[k2];
						nm.children[k].order = order + 1;
						if (nm.children[k].action.path) {
							//syslog2("info", sprintf("cozy_menu: key = '%s' orig path = %s", k, nm.children[k].action.path));
							let p = split(nm.children[k].action.path, "/");
							//syslog2("info", sprintf("cozy_menu: %s", p));
							if (length(p) > 2 && p[0] == "admin" && p[1] == k1) {
								p[1] = nm_name;
								p[2] = k;
								nm.children[k].action.path = join("/", p);
								//syslog2("info", sprintf("cozy_menu: %s = %s (%d)", k, nm.children[k].action.path, length(p)));
							}
						}
						delete menu.children.admin.children[k1].children[k2];
					}
				}
			}
		}
		menu.children.admin.children[nm_name] = nm;
	}
	//dump2file("/tmp/menu2.json", menu);
	return menu;
}

export { cozymenu_hook }; 
