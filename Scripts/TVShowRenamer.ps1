# Load Windows Forms for GUI prompts
Add-Type -AssemblyName System.Windows.Forms

# --- GUI SECTION: Prompt for Show Name and Season Number ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'TV Show Renamer'
$form.Size = New-Object System.Drawing.Size(350, 180)
$form.StartPosition = 'CenterScreen'

# Show Name Label and TextBox
$label1 = New-Object System.Windows.Forms.Label
$label1.Text = 'Show Name:'
$label1.Location = '10,20'
$form.Controls.Add($label1)
$textBox1 = New-Object System.Windows.Forms.TextBox
$textBox1.Location = '100,20'
$textBox1.Size = New-Object System.Drawing.Size(200, 20)
$textBox1.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$form.Controls.Add($textBox1)

# Season Number Label and TextBox
$label2 = New-Object System.Windows.Forms.Label
$label2.Text = 'Season #:'
$label2.Location = '10,50'
$form.Controls.Add($label2)
$textBox2 = New-Object System.Windows.Forms.TextBox
$textBox2.Location = '100,50'
$textBox2.Size = New-Object System.Drawing.Size(200, 20)
$textBox2.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$form.Controls.Add($textBox2)

# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = 'OK'
$okButton.Location = '100,90'
$okButton.Add_Click({ $form.Close() })
$form.Controls.Add($okButton)

$form.Topmost = $true
$form.ShowDialog()

# --- GET USER INPUT FROM GUI ---
$showName = $textBox1.Text
$seasonNumber = $textBox2.Text

# Validate input
if ([string]::IsNullOrWhiteSpace($showName) -or [string]::IsNullOrWhiteSpace($seasonNumber)) {
    Write-Host "ERROR: Please enter both show name and season number"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

Write-Host "=== TV Show Renamer Started ==="
Write-Host "Show Name Input: '$showName'"
Write-Host "Season Number: '$seasonNumber'"
Write-Host ""

# --- BUILD THE FOLDER PATH DYNAMICALLY ---
$folderShowName = $showName.ToUpper().Replace(' ', '_')
Write-Host "Converted folder name: '$folderShowName'"

# Build folder path for network share
$tvRoot = "\\10.0.0.124\PlexMedia\Video\TV Shows"
$showFolder = Join-Path $tvRoot $folderShowName
$seasonFolder = Join-Path $showFolder ("Season " + $seasonNumber)

Write-Host "Target folder: '$seasonFolder'"
Write-Host ""

# Check if folder exists before trying to set location
if (Test-Path $seasonFolder) {
    Set-Location $seasonFolder
    Write-Host "Successfully found and accessed folder"
} else {
    Write-Host "ERROR: Folder does not exist: $seasonFolder"
    Write-Host ""
    Write-Host "Checking what folders are available..."
    
    if (Test-Path $showFolder) {
        Write-Host "Available season folders in '$showFolder':"
        Get-ChildItem $showFolder -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    } else {
        Write-Host "Show folder doesn't exist: $showFolder"
        Write-Host ""
        Write-Host "Available shows in '$tvRoot':"
        Get-ChildItem $tvRoot -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    }
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# --- FETCH SHOW YEAR AND EPISODE TITLES FROM TVMAZE ---
Write-Host ""
Write-Host "=== Fetching Show Data from TVMaze ==="
Write-Host "Searching for show: '$showName'"

# Prepare the TVMaze API search URL
$searchUrl = "https://api.tvmaze.com/singlesearch/shows?q=$($showName -replace ' ', '%20')"
Write-Host "API URL: $searchUrl"

try {
    $showData = Invoke-RestMethod -Uri $searchUrl
    Write-Host "Show found: $($showData.name)"
    Write-Host "  Show ID: $($showData.id)"
    Write-Host "  Premiered: $($showData.premiered)"
    
    $showId = $showData.id
    
    # Extract year safely
    if ([string]::IsNullOrEmpty($showData.premiered)) {
        Write-Host "WARNING: No premiere date found, using placeholder year"
        $year = "UNKNOWN"
    } else {
        $year = $showData.premiered.Substring(0, 4)
        Write-Host "  Extracted year: $year"
    }
} catch {
    Write-Host "ERROR: Failed to fetch show data from TVMaze"
    Write-Host "Error details: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "This could be due to:"
    Write-Host "- Internet connection issue"
    Write-Host "- Show name not found on TVMaze"
    Write-Host "- Try using more specific name (e.g., 'The Office US' instead of 'The Office')"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Get all episodes for the show, then filter for this season
Write-Host ""
Write-Host "Fetching episodes for season $seasonNumber..."
$episodesUrl = "https://api.tvmaze.com/shows/$showId/episodes"

try {
    $allEpisodes = Invoke-RestMethod -Uri $episodesUrl
    $episodes = $allEpisodes | Where-Object { $_.season -eq [int]$seasonNumber }
    Write-Host "Found $($episodes.Count) episodes for season $seasonNumber"
    
    if ($episodes.Count -eq 0) {
        Write-Host "ERROR: No episodes found for season $seasonNumber"
        Write-Host ""
        Write-Host "Available seasons for this show:"
        $allEpisodes | Group-Object season | Sort-Object Name | ForEach-Object { 
            Write-Host "  Season $($_.Name): $($_.Count) episodes" 
        }
        Read-Host -Prompt "Press Enter to exit"
        exit
    }
} catch {
    Write-Host "ERROR: Failed to fetch episodes from TVMaze"
    Write-Host "Error details: $($_.Exception.Message)"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Build a mapping: S02E01 = "Title"
Write-Host ""
Write-Host "Building episode title mapping..."
$episodeTitles = @{}
foreach ($ep in $episodes) {
    $epNum = "S{0:D2}E{1:D2}" -f $ep.season, $ep.number
    $episodeTitles[$epNum] = $ep.name
    Write-Host "  $epNum = $($ep.name)"
}

Write-Host "Episode mapping complete. Total episodes mapped: $($episodeTitles.Count)"

# --- RENAME FILES IN THE SEASON FOLDER ---
Write-Host ""
Write-Host "=== Renaming Files ==="
Write-Host "Looking for video files in: $seasonFolder"

# Fixed file detection using -Filter (much more reliable)
$videoFiles = @()
$videoFiles += Get-ChildItem -Path $seasonFolder -Filter "*.mkv" -File
$videoFiles += Get-ChildItem -Path $seasonFolder -Filter "*.mp4" -File

# Sort files to ensure consistent order
$videoFiles = $videoFiles | Sort-Object Name

Write-Host "Found $($videoFiles.Count) video files"

if ($videoFiles.Count -eq 0) {
    Write-Host "No video files found to rename"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

Write-Host ""
Write-Host "Processing files..."

# For each video file, assign sequential episode numbers
$processedFiles = 0
$skippedFiles = 0
$episodeCounter = 1  # Start from episode 1

foreach ($file in $videoFiles) {
    Write-Host ""
    Write-Host "Processing: $($file.Name)"
    
    # Create sequential episode code
    $episodeCode = "S{0:D2}E{1:D2}" -f [int]$seasonNumber, $episodeCounter
    Write-Host "  Assigning: $episodeCode"
    
    # Look up the episode title for this sequential episode
    if ($episodeTitles.ContainsKey($episodeCode)) {
        $title = $episodeTitles[$episodeCode] -replace '[\\/:*?"<>|]', ''
        Write-Host "  Episode title: $title"
        
        # Build the new filename
        $newName = "$showName ($year) - $episodeCode - $title$($file.Extension)"
        Write-Host "  New name: $newName"
        
        try {
            # Rename the file
            Rename-Item -Path $file.FullName -NewName $newName -Verbose
            Write-Host "  Successfully renamed"
            $processedFiles++
        } catch {
            Write-Host "  ERROR renaming file: $($_.Exception.Message)"
            $skippedFiles++
        }
    } else {
        Write-Host "  WARNING: No episode title found for $episodeCode"
        $skippedFiles++
    }
    
    # Increment episode counter for next file
    $episodeCounter++
}



# --- SUMMARY ---
Write-Host ""
Write-Host "=== Renaming Complete ==="
Write-Host "Files processed successfully: $processedFiles"
Write-Host "Files skipped: $skippedFiles"
Write-Host "Total files: $($videoFiles.Count)"

# --- KEEP WINDOW OPEN FOR DEBUGGING ---
Write-Host ""
Read-Host -Prompt "Press Enter to exit"
