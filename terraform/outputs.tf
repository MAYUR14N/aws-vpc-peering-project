output "vpc_ids" {
  value = { a = aws_vpc.a.id, b = aws_vpc.b.id }
}
output "subnet_ids_and_cidrs" {
  value = {
    a_public  = { id = aws_subnet.a_public.id, cidr = aws_subnet.a_public.cidr_block }
    a_private = { id = aws_subnet.a_private.id, cidr = aws_subnet.a_private.cidr_block }
    b_private = { id = aws_subnet.b_private.id, cidr = aws_subnet.b_private.cidr_block }
  }
}
output "route_table_ids" {
  value = {
    a_public  = aws_route_table.a_public.id
    a_private = aws_route_table.a_private.id
    b_private = aws_route_table.b_private.id
  }
}
output "internet_gateway_id" {
  value = aws_internet_gateway.a.id
}
output "peering_connection_id" {
  value = var.enable_peering ? aws_vpc_peering_connection.a_b[0].id : "peering disabled (enable_peering=false)"
}
output "security_group_ids" {
  value = {
    bastion = aws_security_group.bastion.id
    app_a   = aws_security_group.app_a.id
    app_b   = aws_security_group.app_b.id
  }
}
output "instance_ids" {
  value = {
    bastion = aws_instance.bastion.id
    app_a   = aws_instance.app_a.id
    app_b   = aws_instance.app_b.id
  }
}
output "private_ips" {
  value = {
    bastion = aws_instance.bastion.private_ip
    app_a   = aws_instance.app_a.private_ip
    app_b   = aws_instance.app_b.private_ip
  }
}
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
output "app_public_ips_should_be_null" {
  description = "Isolation check: both must be empty."
  value       = { app_a = aws_instance.app_a.public_ip, app_b = aws_instance.app_b.public_ip }
}
output "ssh_config_snippet" {
  description = "Paste into C:\\Users\\<you>\\.ssh\\config (no secrets inside)."
  value       = <<-EOT
    Host ewb-bastion
        HostName ${aws_instance.bastion.public_ip}
        User ec2-user
        IdentityFile ~/.ssh/ewb-lab
        IdentitiesOnly yes

    Host ewb-app-a
        HostName ${aws_instance.app_a.private_ip}
        User ec2-user
        IdentityFile ~/.ssh/ewb-lab
        IdentitiesOnly yes
        ProxyJump ewb-bastion

    Host ewb-app-b
        HostName ${aws_instance.app_b.private_ip}
        User ec2-user
        IdentityFile ~/.ssh/ewb-lab
        IdentitiesOnly yes
        ProxyJump ewb-bastion
  EOT
}
