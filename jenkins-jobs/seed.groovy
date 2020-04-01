node{
  stage("checkout"){
    checkout([$class: 'GitSCM',
        branches: [[name: 'master' ]],
        userRemoteConfigs: [[url: 'https://github.com/michack/jenkins-eks-ecr.git']]])
  }
  stage("seed"){
    jobDsl targets: 'jenkins-jobs/jobs/*.groovy',
           lookupStrategy: 'SEED_JOB',
           removedJobAction: 'DISABLE',  
           removedViewAction: 'IGNORE',
           ignoreExisting: false
  }
}
