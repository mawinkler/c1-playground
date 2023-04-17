resource "aws_key_pair" "cnctraining_key_pair" {
    key_name               = "${var.private_key_path}"
    public_key             = "${file(var.public_key_path)}"
}
