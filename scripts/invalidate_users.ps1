# ========================================================================
# Suraksha+ — Invalidate All Previous Cognito Users
# ========================================================================
# WARNING: This is a DESTRUCTIVE operation. All existing users will be
# disabled and unable to log in. Run only after confirming with the team.
#
# Prerequisites:
#   - AWS CLI installed and configured with appropriate IAM permissions
#   - Permissions: cognito-idp:ListUsers, cognito-idp:AdminDisableUser
#
# Usage:
#   .\invalidate_users.ps1
#
# To DELETE users instead of disabling, uncomment the delete line below.
# ========================================================================

$UserPoolId = "ap-south-1_IrCwWGqNy"
$Region = "ap-south-1"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host " Suraksha+ — Cognito User Invalidation" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "User Pool: $UserPoolId" -ForegroundColor Cyan
Write-Host "Region:    $Region" -ForegroundColor Cyan
Write-Host ""

# Confirmation prompt
$confirm = Read-Host "Are you sure you want to DISABLE all users in this pool? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Fetching users..." -ForegroundColor Yellow

$paginationToken = $null
$totalDisabled = 0

do {
    $params = @(
        "cognito-idp", "list-users",
        "--user-pool-id", $UserPoolId,
        "--region", $Region,
        "--max-results", "60"
    )

    if ($paginationToken) {
        $params += "--pagination-token"
        $params += $paginationToken
    }

    $result = aws @params | ConvertFrom-Json

    if (-not $result.Users -or $result.Users.Count -eq 0) {
        Write-Host "No users found." -ForegroundColor Green
        break
    }

    foreach ($user in $result.Users) {
        $username = $user.Username
        $email = ($user.Attributes | Where-Object { $_.Name -eq "email" }).Value

        Write-Host "Disabling: $username ($email)..." -ForegroundColor Red -NoNewline

        try {
            aws cognito-idp admin-disable-user `
                --user-pool-id $UserPoolId `
                --username $username `
                --region $Region 2>&1 | Out-Null

            # Uncomment the line below to DELETE users instead of disabling:
            # aws cognito-idp admin-delete-user --user-pool-id $UserPoolId --username $username --region $Region 2>&1 | Out-Null

            Write-Host " DONE" -ForegroundColor Green
            $totalDisabled++
        }
        catch {
            Write-Host " FAILED: $_" -ForegroundColor Red
        }
    }

    $paginationToken = $result.PaginationToken
} while ($paginationToken)

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host " Complete! $totalDisabled user(s) disabled." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Yellow
