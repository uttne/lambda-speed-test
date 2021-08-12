$OLD_DIR = Get-Location

$WORK_DIR = $(Split-Path -Parent $MyInvocation.MyCommand.Path)

Set-Location $WORK_DIR

$LAMBDA_ROLE_NAME = "lambda-speed-test-role"

function New-Role(){
    if($(aws iam list-roles --query "Roles[].[RoleName]" | sls $LAMBDA_ROLE_NAME)){
        Write-Output "'$LAMBDA_ROLE_NAME' is existed."
        return
    }
    aws iam create-role --role-name $LAMBDA_ROLE_NAME --assume-role-policy-document file://lambda-speed-test-role-trust-policy.json --no-cli-pager
    aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn "arn:aws:iam::aws:policy/AWSLambdaExecute"
    Write-Output "'$LAMBDA_ROLE_NAME' create."
}

try{

    New-Role

    pwsh "./dotnet-core-3.1/build.ps1"
}
finally{
    Set-Location $OLD_DIR
}