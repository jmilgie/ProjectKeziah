function Publish-ProjectKeziah {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitHubUsername,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        
        [Parameter(Mandatory = $false)]
        [string]$PersonalAccessToken,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseSSHKey,
        
        [Parameter(Mandatory = $false)]
        [string]$CommitMessage = "Initial commit"
    )
    
    # Validate GitHub CLI is installed
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/" -ForegroundColor Red
        return
    }
    
    # Validate Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Please install it from https://git-scm.com/" -ForegroundColor Red
        return
    }
    
    # Validate the project folder exists
    if (-not (Test-Path $ProjectPath)) {
        Write-Host "Project folder not found at path: $ProjectPath" -ForegroundColor Red
        return
    }
    
    # Get the full path to the project directory
    $projectFullPath = (Resolve-Path $ProjectPath).Path
    
    # Extract the project name from the path
    $projectName = Split-Path $projectFullPath -Leaf
    
            # Check for project folders - No2 is required, No1 is optional
    $no2SiteFolderPath = Join-Path $projectFullPath "Visual-Metaphysics-No2-Reincarnation\site"
    $no1SiteFolderPath = Join-Path $projectFullPath "Visual-Metaphysics-No1-FlyingSaucers\site"
    
    if (-not (Test-Path $no2SiteFolderPath)) {
        Write-Host "Site folder not found at: $no2SiteFolderPath" -ForegroundColor Red
        return
    }
    
    $hasNo1Folder = Test-Path $no1SiteFolderPath
    if ($hasNo1Folder) {
        Write-Host "Found Visual-Metaphysics-No1-FlyingSaucers folder. Will include in deployment." -ForegroundColor Green
    }
    
    # Check if index.html exists in the root
    $indexPath = Join-Path $projectFullPath "index.html"
    $hasIndexFile = Test-Path $indexPath
    if (-not $hasIndexFile) {
        Write-Host "WARNING: index.html not found in the project root. Main landing page will not be published." -ForegroundColor Yellow
        Write-Host "To add a landing page, create an index.html file in the root directory of your project." -ForegroundColor Yellow
    }
    
    # Set GitHub authentication if PAT is provided
    if ($PersonalAccessToken) {
        Write-Host "Authenticating with GitHub using Personal Access Token..." -ForegroundColor Yellow
        $env:GITHUB_TOKEN = $PersonalAccessToken
        gh auth status
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Authentication failed. Please check your Personal Access Token." -ForegroundColor Red
            return
        }
    }
    else {
        # Verify if the user is already authenticated
        Write-Host "Checking GitHub authentication status..." -ForegroundColor Yellow
        gh auth status
        if ($LASTEXITCODE -ne 0) {
            Write-Host "You're not authenticated with GitHub. Please run 'gh auth login' first or provide a Personal Access Token." -ForegroundColor Red
            return
        }
    }
    
    try {
        # Create GitHub repository
        Write-Host "Creating GitHub repository: $projectName..." -ForegroundColor Yellow
        gh repo create $projectName --public --confirm
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to create repository. It might already exist or there might be a permission issue." -ForegroundColor Red
            return
        }
        
        # Initialize Git in the project directory if it's not already a Git repository
        Push-Location $projectFullPath
        if (-not (Test-Path (Join-Path $projectFullPath ".git"))) {
            Write-Host "Initializing Git repository in project folder..." -ForegroundColor Yellow
            git init
        }
        
        # Add GitHub remote
        Write-Host "Setting up GitHub remote..." -ForegroundColor Yellow
        if ($UseSSHKey) {
            git remote add origin "git@github.com:$GitHubUsername/$projectName.git" -ErrorAction SilentlyContinue
        }
        else {
            git remote add origin "https://github.com/$GitHubUsername/$projectName.git" -ErrorAction SilentlyContinue
        }
        
        # Create GitHub Pages workflow for the site folder
        Write-Host "Setting up GitHub Actions workflow for GitHub Pages..." -ForegroundColor Yellow
        $workflowsDir = Join-Path $projectFullPath ".github\workflows"
        New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
        
        $workflowContent = @"
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]
  workflow_dispatch:

# Sets permissions of the GITHUB_TOKEN to allow deployment to GitHub Pages
permissions:
  contents: read
  pages: write
  id-token: write

# Allow only one concurrent deployment, skipping runs queued between the run in-progress and latest queued.
concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: `${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Create deployment directory
        run: mkdir -p ./deploy
        
      - name: Copy main landing page
        run: |
          if [ -f "./index.html" ]; then
            cp ./index.html ./deploy/
          fi
      
      - name: Create project directories
        run: |
          mkdir -p ./deploy/Visual-Metaphysics-No2-Reincarnation/site
      
      - name: Copy project site files
        run: |
          cp -r ./Visual-Metaphysics-No2-Reincarnation/site/* ./deploy/Visual-Metaphysics-No2-Reincarnation/site/
      
      - name: Setup Pages
        uses: actions/configure-pages@v4
        
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: './deploy'
          
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
"@
        
        $workflowContent | Out-File -FilePath (Join-Path $workflowsDir "deploy-pages.yml") -Encoding UTF8
        
        # Create a README file
        $readmeContent = @"
# $projectName

This repository contains the Visual Metaphysics No. 2: Reincarnation project by Fred Keziah (1957).

## About

This site is a digital recreation project for Fred Keziah's "Visual Metaphysics No. 2: Reincarnation" chart from 1957.

## Development

To make changes to this site:

1. Modify files in the \`Visual-Metaphysics-No2-Reincarnation/site\` directory
2. To update the main landing page, edit the \`index.html\` file in the root directory
3. Commit and push to GitHub
4. GitHub Actions will automatically deploy to GitHub Pages

## Live Site

The site is available at: https://$GitHubUsername.github.io/$projectName/
"@
        
        $readmeContent | Out-File -FilePath (Join-Path $projectFullPath "README.md") -Encoding UTF8
        
        # Add all files to git
        Write-Host "Adding files to Git..." -ForegroundColor Yellow
        git add .
        
        # Commit changes
        Write-Host "Committing changes..." -ForegroundColor Yellow
        git commit -m $CommitMessage
        
        # Push to GitHub
        Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
        git push -u origin main
        
        # Automatically configure GitHub Pages settings via the GitHub API
        Write-Host "Configuring GitHub Pages settings..." -ForegroundColor Yellow
        
        # Configure workflow permissions
        $permissionPayload = @{
            enabled = $true
            can_approve_pull_request_reviews = $true
        } | ConvertTo-Json

        Write-Host "Setting repository workflow permissions..." -ForegroundColor Yellow
        $token = if ($PersonalAccessToken) { $PersonalAccessToken } else { gh auth token }
        
        $headers = @{
            'Accept' = 'application/vnd.github+json'
            'Authorization' = "Bearer $token"
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        
        # Set workflow permissions to read/write
        try {
            Invoke-RestMethod `
                -Uri "https://api.github.com/repos/$GitHubUsername/$projectName/actions/permissions" `
                -Method PUT `
                -Headers $headers `
                -Body $permissionPayload `
                -ContentType 'application/json'
        }
        catch {
            Write-Host "Warning: Could not set workflow permissions. You may need to set this manually." -ForegroundColor Yellow
        }
        
        # Configure GitHub Pages to use GitHub Actions
        try {
            # First we need to enable GitHub Pages which creates the resource
            $enablePagesPayload = @{
                source = @{
                    branch = "main"
                    path = "/"
                }
            } | ConvertTo-Json
            
            Write-Host "Enabling GitHub Pages first..." -ForegroundColor Yellow
            Invoke-RestMethod `
                -Uri "https://api.github.com/repos/$GitHubUsername/$projectName/pages" `
                -Method POST `
                -Headers $headers `
                -Body $enablePagesPayload `
                -ContentType 'application/json'
                
            # Give GitHub some time to initialize the Pages configuration
            Write-Host "Waiting for GitHub Pages initialization..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            
            # Now update to use GitHub Actions
            $pagesPayload = @{
                build_type = "workflow"
            } | ConvertTo-Json
            
            Write-Host "Configuring GitHub Pages to use GitHub Actions..." -ForegroundColor Yellow
            Invoke-RestMethod `
                -Uri "https://api.github.com/repos/$GitHubUsername/$projectName/pages" `
                -Method PUT `
                -Headers $headers `
                -Body $pagesPayload `
                -ContentType 'application/json'
        }
        catch {
            Write-Host "Warning: Could not automatically configure GitHub Pages settings. You may need to manually configure them." -ForegroundColor Yellow
            Write-Host "To configure manually, go to: https://github.com/$GitHubUsername/$projectName/settings/pages" -ForegroundColor Yellow
            Write-Host "  - Under 'Build and deployment' source, select 'GitHub Actions'" -ForegroundColor Yellow
        }
        
        # Trigger the workflow manually with retry logic
        Write-Host "Triggering GitHub Pages workflow..." -ForegroundColor Yellow
        
        # First try running the workflow directly
        try {
            gh workflow run deploy-pages.yml --repo "$GitHubUsername/$projectName"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Workflow triggered successfully!" -ForegroundColor Green
            } else {
                Write-Host "Could not trigger workflow through gh CLI. Trying alternative method..." -ForegroundColor Yellow
                
                # Alternative method: Create an empty commit to trigger the workflow
                Write-Host "Creating an empty commit to trigger workflow..." -ForegroundColor Yellow
                git commit --allow-empty -m "Trigger GitHub Pages deployment"
                git push
                
                # Force trigger the workflow using the GitHub API
                Write-Host "Force-triggering the workflow via GitHub API..." -ForegroundColor Yellow
                try {
                    Invoke-RestMethod `
                        -Uri "https://api.github.com/repos/$GitHubUsername/$projectName/actions/workflows/deploy-pages.yml/dispatches" `
                        -Method POST `
                        -Headers $headers `
                        -Body "{`"ref`":`"main`"}" `
                        -ContentType 'application/json'
                    
                    Write-Host "Workflow dispatch API call successful!" -ForegroundColor Green
                } catch {
                    Write-Host "API call to trigger workflow failed. You may need to trigger it manually." -ForegroundColor Yellow
                    Write-Host "  - Go to https://github.com/$GitHubUsername/$projectName/actions" -ForegroundColor Yellow
                    Write-Host "  - Click on the 'Deploy to GitHub Pages' workflow" -ForegroundColor Yellow
                    Write-Host "  - Click 'Run workflow' button in the blue banner" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "Error triggering workflow: $_" -ForegroundColor Yellow
            Write-Host "You may need to trigger the workflow manually:" -ForegroundColor Yellow
            Write-Host "  - Go to https://github.com/$GitHubUsername/$projectName/actions" -ForegroundColor Yellow
            Write-Host "  - Click on the 'Deploy to GitHub Pages' workflow" -ForegroundColor Yellow
            Write-Host "  - Click 'Run workflow' button in the blue banner" -ForegroundColor Yellow
        }
        
        Write-Host "`nPublishing complete!" -ForegroundColor Green
        Write-Host "Your project has been pushed to GitHub: https://github.com/$GitHubUsername/$projectName" -ForegroundColor Green
        
        if ($hasIndexFile) {
            Write-Host "Landing page detected! Your site will be available at: https://$GitHubUsername.github.io/$projectName/" -ForegroundColor Green
            Write-Host "Project page will be available at: https://$GitHubUsername.github.io/$projectName/Visual-Metaphysics-No2-Reincarnation/site/landing-page.html" -ForegroundColor Green
        } else {
            Write-Host "Your site will be available at: https://$GitHubUsername.github.io/$projectName/Visual-Metaphysics-No2-Reincarnation/site/landing-page.html" -ForegroundColor Green
            Write-Host "To add a landing page, create an index.html file in the root directory." -ForegroundColor Yellow
        }
        
        Write-Host "Note: It may take a few minutes for the site to be published." -ForegroundColor Yellow
        
        # Instructions for future updates
        Write-Host "`nTo update your project in the future:" -ForegroundColor Yellow
        Write-Host "  1. Make your changes in the project directory" -ForegroundColor Yellow
        Write-Host "  2. Run these commands from the $projectFullPath directory:" -ForegroundColor Yellow
        Write-Host "     git add ." -ForegroundColor Yellow
        Write-Host "     git commit -m 'Your update message'" -ForegroundColor Yellow
        Write-Host "     git push" -ForegroundColor Yellow
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
    finally {
        # Return to the original location
        Pop-Location
        
        # Remove token from environment if it was set
        if ($PersonalAccessToken) {
            Remove-Item env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        }
    }
}