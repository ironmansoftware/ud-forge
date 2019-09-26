Start-UDDashboard -Dashboard (New-UDDashboard -Title 'Dashboard' -Content {
    New-UDInput -Title "Say Hello" -Endpoint {
        param($Message)
        
        New-BurntToastNotification -Text $Message
    }
}) -Port 8001 -Wait