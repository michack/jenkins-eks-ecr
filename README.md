## JENKINS-EKS-ECR

Repository contains:
- terraform code to create AWS EKS cluster along with ECR repository
- terraform code to automatically deploy publicly available (ELB) jenkins pod:
  - build jenkins image from Dockerfile
  - push the image to ECR
  - deploy jenkins image from ECR to EKS
- Dockerfile which is used to create jenkins image
- definition of jenkins job which deploys other apps to EKS

Requirements:
* [terraform](https://www.terraform.io/) (tested on v0.12.4)
* [awscli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html) (tested on 1.17.1)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (tested on v1.17.0)

Steps:
1. create s3 bucket (or use existing one) to store terraform state files remotely:
```
aws s3 mb s3://BUCKET_NAME
```
2. execute terraform code in order to create EKS cluster and ECR repo (view and edit `vars/aws-eks.tfvars` if needed)
```sh
cd terraform/eks_stack
terraform init -backend-config=backends/aws-eks.tfvars -backend-config="bucket=BUCKET_NAME"
terraform plan -var-file=vars/aws-eks.tfvars
terraform apply -var-file=vars/aws-eks.tfvars
```
be patient, EKS creation takes time.

3. Terraform will create `kubeconfig` for you. By default it is stored in /tmp/kubeconfig_eks.txt file. Edit `vars/aws-eks.tfvars` to change the location of the file. Once the terraform is finished you should be able to access EKS by executing the following command:
```sh
$ KUBECONFIG=/tmp/kubeconfig_eks.txt kubectl get pods -A
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
kube-system   aws-node-h5msj             1/1     Running   0          6m10s
kube-system   aws-node-knz9w             1/1     Running   0          6m22s
kube-system   coredns-86d5cbb4bd-bv4zv   1/1     Running   0          11m
kube-system   coredns-86d5cbb4bd-w4hq7   1/1     Running   0          11m
kube-system   kube-proxy-2t8kc           1/1     Running   0          6m22s
kube-system   kube-proxy-m6ws7           1/1     Running   0          6m10s
```
4. Execute terraform code in order to create kubernetes resources (jenkins pod with ELB LoadBalancer).
```sh
cd terraform/k8s_stack
terraform init -backend-config=backends/aws-eks.tfvars -backend-config="bucket=BUCKET_NAME"
terraform plan -var-file=vars/aws-eks.tfvars -var 'bucket_name=BUCKET_NAME'
terraform apply -var-file=vars/aws-eks.tfvars -var 'bucket_name=BUCKET_NAME'
```
5. Jenkins image will be created based on `docker/jenkins/Dockerfile`. The image will be pushed to ECR and then deployed to EKS. Building and pushing takes time so be patient. Jenkins public endpoint will be displayed in terraform output:
```
Outputs:

jenkins_elb_hostname = http://aa490d45e0e2b46128e96ea2ea4518ab-1272224324.us-west-2.elb.amazonaws.com:8080
```

Jenkins uses [configuration as code plugin](https://github.com/jenkinsci/configuration-as-code-plugin), and its config is placed in `docker/jenkins/files/jenkins.yaml`. Credentials are defined in: jenkins.securityRealm.local.users.

6. Login to jenkins and execute `seed` job. Seed job will create additional job (`general_builder`) which is described in `jenkins-jobs` directory. Refresh Jenkins page once the seed job is executed.

7. General_builder is a job, which executed with default parameters, will build, push and deploy [webapp-demo](https://github.com/michack/webapp-demo) application to EKS.

```sh
$ KUBECONFIG=/tmp/kubeconfig_eks.txt kubectl get pods
NAME                           READY   STATUS    RESTARTS   AGE
jenkins-5b878f4c9c-6zw4q       1/1     Running   0          8m42s
webapp-demo-659f9fc6f5-jl89j   1/1     Running   0          17s
```

`kubectl get service` will show external endpoint for webapp application:
```sh
$ KUBECONFIG=/tmp/kubeconfig_eks.txt kubectl get service
NAME          TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)          AGE
jenkins       LoadBalancer   172.20.158.115   aa490d45e0e2b46128e96ea2ea4518ab-1272224324.us-west-2.elb.amazonaws.com   8080:31496/TCP   28m
kubernetes    ClusterIP      172.20.0.1       <none>                                                                    443/TCP          44m
webapp-demo   LoadBalancer   172.20.220.79    a00cb4166bb8d4d7781f5807a224ceb4-1559019708.us-west-2.elb.amazonaws.com   80:32431/TCP     3m39s
```
8. ELB needs few minutes to be fully operational. Open webapp endpoint, it should display: "Hello!".

# Cleaning up
1. destroy webapp deployment and service:
```sh
KUBECONFIG=/tmp/kubeconfig_eks.txt kubectl delete deployment webapp-demo
KUBECONFIG=/tmp/kubeconfig_eks.txt kubectl delete service webapp-demo
```

2. destroy kubernetes resources:
```sh
cd terraform/k8s_stack
terraform plan -var-file=vars/aws-eks.tfvars -var 'bucket_name=BUCKET_NAME' -destroy
terraform destroy -var-file=vars/aws-eks.tfvars -var 'bucket_name=BUCKET_NAME'
```

3. destroy aws resources:
```sh
cd terraform/eks_stack
terraform plan -var-file=vars/aws-eks.tfvars -destroy
terraform destroy -var-file=vars/aws-eks.tfvars
```
4. remove kubeconfig:
`rm -f /tmp/kubernetes.txt`

5. remove s3 bucket with terraform states:
`aws s3 rb s3://BUCKET_NAME --force`

