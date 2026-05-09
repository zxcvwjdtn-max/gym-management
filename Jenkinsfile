// ═══════════════════════════════════════════════════════════════
//  gym-management 배포 파이프라인
//  Android APK + Flutter Web + Windows 데스크탑
//  develop → 개발 서버 자동 배포
//  main    → 운영 서버 수동 승인 후 배포
//
//  Jenkins 전역 환경변수 설정 필요:
//    DEV_SERVER_IP, PROD_SERVER_IP, DEPLOY_USER
//
//  Jenkins Credentials 설정 필요:
//    deploy-server-ssh : SSH Private Key
//
//  Windows 빌드는 'windows-agent' 라벨의 Jenkins 에이전트 필요
//    (에이전트에 Flutter SDK 설치 필요)
// ═══════════════════════════════════════════════════════════════
pipeline {
    agent none

    environment {
        APP_DIR      = '.'
        APP_ID       = 'gym-management'
        WEB_HREF     = '/management/'
        DEV_SERVER   = "${env.DEV_SERVER_IP}"
        PROD_SERVER  = "${env.PROD_SERVER_IP}"
        DEPLOY_USER  = "${env.DEPLOY_USER ?: 'ubuntu'}"
        DEV_WEB_DIR  = '/opt/gympro/dev/web/gym-management'
        PROD_WEB_DIR = '/opt/gympro/prod/web/gym-management'
        DEV_DL_DIR   = '/opt/gympro/dev/downloads'
        PROD_DL_DIR  = '/opt/gympro/prod/downloads'
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
    }

    stages {

        // ══════════════════════════════════════════════════════
        //  개발 배포 (develop 브랜치)
        // ══════════════════════════════════════════════════════

        stage('DEV: Android + Web 빌드 & 배포') {
            when { branch 'dev' }
            agent any
            stages {
                stage('의존성') {
                    steps { dir(APP_DIR) { sh 'flutter pub get' } }
                }

                stage('Android DEV 빌드') {
                    steps {
                        dir(APP_DIR) {
                            sh 'flutter build apk --debug'
                        }
                    }
                }

                stage('Web DEV 빌드') {
                    steps {
                        dir(APP_DIR) {
                            sh "flutter build web --release --base-href='${WEB_HREF}'"
                        }
                    }
                }

                stage('DEV 서버 배포') {
                    steps {
                        sshagent(credentials: ['deploy-server-ssh']) {
                            sh """
                                # Android APK 업로드
                                scp -o StrictHostKeyChecking=no \
                                    ${APP_DIR}/build/app/outputs/flutter-apk/app-debug.apk \
                                    ${DEPLOY_USER}@${DEV_SERVER}:${DEV_DL_DIR}/apk/${APP_ID}-debug.apk

                                # Web 파일 업로드
                                ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEV_SERVER} \
                                    'rm -rf ${DEV_WEB_DIR}/* && mkdir -p ${DEV_WEB_DIR}'
                                scp -r -o StrictHostKeyChecking=no \
                                    ${APP_DIR}/build/web/. \
                                    ${DEPLOY_USER}@${DEV_SERVER}:${DEV_WEB_DIR}/
                            """
                        }
                    }
                    post {
                        success {
                            echo "✅ DEV 배포 완료"
                            echo "   APK: http://${DEV_SERVER}:8082/downloads/apk/${APP_ID}-debug.apk"
                            echo "   Web: http://${DEV_SERVER}:8082${WEB_HREF}"
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  운영 배포 (main 브랜치)
        // ══════════════════════════════════════════════════════

        stage('PROD: 승인') {
            when { branch 'main' }
            agent none
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: "⚠️ [gym-management] 운영 배포를 진행하시겠습니까? (#${BUILD_NUMBER})",
                          ok: '배포 승인'
                }
            }
        }

        stage('PROD: Android + Web 빌드 & 배포') {
            when { branch 'main' }
            agent any
            stages {
                stage('의존성') {
                    steps { dir(APP_DIR) { sh 'flutter pub get' } }
                }

                stage('Android PROD 빌드') {
                    steps {
                        dir(APP_DIR) {
                            sh 'flutter build apk --release'
                        }
                    }
                }

                stage('Web PROD 빌드') {
                    steps {
                        dir(APP_DIR) {
                            sh "flutter build web --release --base-href='${WEB_HREF}'"
                        }
                    }
                }

                stage('PROD 서버 배포') {
                    steps {
                        sshagent(credentials: ['deploy-server-ssh']) {
                            sh """
                                # Android APK 업로드
                                scp -o StrictHostKeyChecking=no \
                                    ${APP_DIR}/build/app/outputs/flutter-apk/app-release.apk \
                                    ${DEPLOY_USER}@${PROD_SERVER}:${PROD_DL_DIR}/apk/${APP_ID}-release.apk

                                # Web 파일 업로드
                                ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${PROD_SERVER} \
                                    'rm -rf ${PROD_WEB_DIR}/* && mkdir -p ${PROD_WEB_DIR}'
                                scp -r -o StrictHostKeyChecking=no \
                                    ${APP_DIR}/build/web/. \
                                    ${DEPLOY_USER}@${PROD_SERVER}:${PROD_WEB_DIR}/
                            """
                        }
                    }
                    post {
                        success {
                            echo "✅ PROD 배포 완료"
                            echo "   APK: http://${PROD_SERVER}/downloads/apk/${APP_ID}-release.apk"
                            echo "   Web: http://${PROD_SERVER}${WEB_HREF}"
                        }
                    }
                }
            }
        }


    }

    post {
        always { echo "빌드 #${BUILD_NUMBER} [${env.BRANCH_NAME}] 완료: ${currentBuild.currentResult}" }
    }
}
