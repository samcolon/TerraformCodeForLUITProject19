output "alb_dns_name" {
  description = "DNS Name for the HolidayGifts ALB"
  value       = aws_lb.holidaygifts_alb.dns_name
}
