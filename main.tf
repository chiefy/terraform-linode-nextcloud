
resource "linode_linode" "nextcloud" {
	image = "Ubuntu 14.04 LTS"
	kernel = "Latest 64 bit"
	name = "nextcloud"
	region = "${var.linode_region}"
	size = "${var.linode_size}"
	private_networking = false
	ssh_key = "${file(var.ssh_key_file)}"
	root_password = "${var.root_password}"
}
