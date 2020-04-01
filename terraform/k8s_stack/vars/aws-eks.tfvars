environment = {
    name = "aws-eks"
}

default_tags = {
    environment = "aws-eks"
}

bucket_name = BUCKET_NAME

jenkins_docker_url = "https://github.com/michack/jenkins-ecr-eks.git#master:docker/jenkins"
