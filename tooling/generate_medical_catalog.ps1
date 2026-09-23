param(
    [string]$SourceUrl = "https://medlineplus.gov/xml/mplus_topics_compressed_2026-09-22.zip"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot "assets\catalog\medlineplus_topics.json"
$temporaryZip = [System.IO.Path]::GetTempFileName()

try {
    curl.exe -L --fail --silent --show-error $SourceUrl --output $temporaryZip
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($temporaryZip)
    try {
        $entry = $archive.Entries |
            Where-Object { $_.FullName -like "*.xml" } |
            Select-Object -First 1
        if ($null -eq $entry) {
            throw "The MedlinePlus archive does not contain an XML file."
        }
        $reader = New-Object System.IO.StreamReader(
            $entry.Open(),
            [System.Text.Encoding]::UTF8,
            $true
        )
        try {
            [xml]$document = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $archive.Dispose()
    }

    $topics = foreach ($topic in $document.'health-topics'.'health-topic') {
        if ($topic.GetAttribute("language") -ne "English") {
            continue
        }
        $summary = ""
        $summaryNode = $topic.SelectSingleNode("full-summary")
        if ($null -ne $summaryNode) {
            $summary = [System.Net.WebUtility]::HtmlDecode(
                $summaryNode.InnerText
            )
            $summary = [regex]::Replace($summary, "<[^>]+>", " ")
            $summary = [System.Net.WebUtility]::HtmlDecode($summary)
            $summary = [regex]::Replace($summary, "\s+", " ").Trim()
        }
        $aliases = @(
            $topic.SelectNodes("also-called") |
                ForEach-Object { $_.InnerText.Trim() } |
                Where-Object { $_ }
        )
        $groups = @(
            $topic.SelectNodes("group") |
                ForEach-Object { $_.InnerText.Trim() } |
                Where-Object { $_ }
        )
        [ordered]@{
            id = "medlineplus-$($topic.GetAttribute("id"))"
            title = $topic.GetAttribute("title")
            summary = $summary
            aliases = $aliases
            groups = $groups
            url = $topic.GetAttribute("url")
            language = "en"
            source = "MedlinePlus.gov, U.S. National Library of Medicine"
        }
    }

    $payload = [ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        sourceUrl = $SourceUrl
        attribution = "Health topic information from MedlinePlus.gov"
        licenseNote = "Text data distributed under the MedlinePlus usage policy; no MedlinePlus images are bundled."
        topics = @($topics)
    }
    $json = $payload | ConvertTo-Json -Depth 8 -Compress
    [System.IO.File]::WriteAllText(
        $outputPath,
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Output "Wrote $($topics.Count) English topics to $outputPath"
}
finally {
    if (Test-Path -LiteralPath $temporaryZip) {
        Remove-Item -LiteralPath $temporaryZip -Force
    }
}
