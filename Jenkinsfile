pipeline {
  agent any
  stages {
    stage('Compile') {
      steps {
        sh '''export GPG_TTY=$(tty);
mvn clean install appassembler:assemble'''
      }
    }
    stage('archive') {
      parallel {
        stage('Archive tests') {
          steps {
            junit(testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true)
          }
        }
        stage('Package') {
          steps {
            sh 'cp src/main/resources/log4j2.xml target/chat-bot; tar -cvzf target/chatbot.tar target/chat-bot'
            archiveArtifacts 'target/*.tar'
          }
        }
      }
    }
  }
}
