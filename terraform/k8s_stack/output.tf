output "jenkins_elb_hostname" {
  value = "http://${kubernetes_service.jenkins.load_balancer_ingress[0].hostname}:8080"
}
