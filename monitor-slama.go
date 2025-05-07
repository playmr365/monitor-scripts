package main

import (
	"fmt"
	"log"
        "net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/coreos/go-systemd/v22/dbus"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
	"gopkg.in/ini.v1"
)

type Config struct {
	DebugMode            string
	LogFile              string
	CpuThreshold         float64
	RamMin               uint64
	DiskThreshold        float64
	DiskPartitions       []string
	AlertInterval        time.Duration
	MaxAlertPriorityTime time.Duration
	NtfyServer           string
	Services             []string
	RestartCooldown      time.Duration
	Autorestart          bool
}
var lastAlert = make(map[string][]time.Time) // Každý alert má slice časů
var (
	cfg          Config
	conn         *dbus.Conn
)

func init() {
	cfg = Config{
		DebugMode:            "normal",
		LogFile:              "/var/log/monitor-slama.log",
		CpuThreshold:         70,
		RamMin:               1024,
		DiskThreshold:        80,
		DiskPartitions:       []string{"/"},
		AlertInterval:        10 * time.Minute,
		MaxAlertPriorityTime: 30 * time.Minute,
		NtfyServer:           "http://ntfy.sh",
		RestartCooldown:      5 * time.Minute,
	}
}


func main() {
	loadConfig()
	setupLogging()
	checkRequirements()

	var err error
	conn, err = dbus.NewSystemConnection()
	if err != nil {
		log.Fatal("DBus connection error:", err)
	}
	defer conn.Close()

	go monitorCPU()
	go monitorRAM()
	go monitorDisk()
	go monitorServices()

	select {} // Blokuj hlavní vlákno
}

func getLocalIP() string {
    addrs, err := net.InterfaceAddrs()
    if err != nil {
        return "unknown"
    }
    for _, addr := range addrs {
        if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() && ipnet.IP.To4() != nil {
            return ipnet.IP.String()
        }
    }
    return "unknown"
}


func loadConfig() {
	cfgFile := "/etc/monitor-slama.conf"
	if _, err := os.Stat(cfgFile); os.IsNotExist(err) {
		return
	}

	iniCfg, err := ini.Load(cfgFile)
	if err != nil {
		log.Fatal("Chyba konfigurace:", err)
	}

	section := iniCfg.Section("")
	cfg.DebugMode = section.Key("DEBUG_MODE").MustString("normal")
	cfg.LogFile = section.Key("LOG_FILE").MustString(cfg.LogFile)
	cfg.CpuThreshold = section.Key("CPU_THRESHOLD").MustFloat64(70)
	cfg.RamMin = section.Key("RAM_MIN").MustUint64(1024)
	cfg.DiskThreshold = section.Key("DISK_THRESHOLD").MustFloat64(80)
	cfg.DiskPartitions = strings.Split(
		section.Key("DISK_PARTITIONS").MustString("/"), ",")
	cfg.NtfyServer = section.Key("NTFY_SERVER").MustString("http://ntfy.sh")
	cfg.Services = strings.Split(
		section.Key("SERVICES").MustString(""), ",")
	cfg.Autorestart = section.Key("AUTORESTART").MustBool(false)
}

func setupLogging() {
	logFile, err := os.OpenFile(cfg.LogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal(err)
	}
	log.SetOutput(logFile)
}

func checkRequirements() {
	required := []string{"mpstat", "df"}
	for _, cmd := range required {
		if _, err := exec.LookPath(cmd); err != nil {
			log.Printf("CHYBA: Chybí požadovaný nástroj %s", cmd)
		}
	}
}

func monitorCPU() {
	for {
		percent, _ := cpu.Percent(time.Second, false)
		usage := percent[0]
		
		if cfg.DebugMode == "dev" {
			log.Printf("DEBUG: Využití CPU: %.2f%%", usage)
		}

		if usage > cfg.CpuThreshold {
			sendAlert(fmt.Sprintf("Vysoké vytížení CPU: %.2f%%", usage))
		}
		time.Sleep(1 * time.Second)
	}
}

func monitorRAM() {
	for {
		v, _ := mem.VirtualMemory()
		freeMB := v.Available / 1024 / 1024

		if cfg.DebugMode == "dev" {
			log.Printf("DEBUG: Dostupné RAM: %d MB", freeMB)
		}

		if freeMB < cfg.RamMin {
			sendAlert(fmt.Sprintf("Nízká volná RAM: %d MB", freeMB))
		}
		time.Sleep(1 * time.Second)
	}
}


func monitorDisk() {
hostname, err := os.Hostname()
if err != nil {
    hostname = "unknown"
}

    for {
        for _, partition := range cfg.DiskPartitions {
            diskStat, err := disk.Usage(partition)
            if err != nil || diskStat == nil {
                log.Printf("Chyba čtení disku %s: %v", partition, err)
                continue
            }

            if cfg.DebugMode == "dev" {
                log.Printf("DEBUG: Disk %s - %.2f%%", partition, diskStat.UsedPercent)
            }

            if diskStat.UsedPercent > cfg.DiskThreshold {
                msg := fmt.Sprintf("Disk %s %.1f%% na %s", partition, diskStat.UsedPercent, hostname)
                sendAlert(msg)
            }
        }
        time.Sleep(1 * time.Second)
    }
}

func monitorServices() {
	for {
		for _, service := range cfg.Services {
			status, err := conn.GetUnitProperty(service, "ActiveState")
			if err != nil {
				log.Printf("CHYBA: Stav služby %s: %v", service, err)
				continue
			}

			if status.Value.String() != "\"active\"" {
				sendAlert(fmt.Sprintf("Služba %s neběží", service))
				if cfg.Autorestart {
					_, err = conn.RestartUnit(service, "fail", nil)
					if err != nil {
						log.Printf("CHYBA: Restart služby %s: %v", service, err)
					}
				}
			}
		}
		time.Sleep(5 * time.Second)
	}
}

func sendAlert(message string) {
    now := time.Now()
    hash := fmt.Sprintf("%x", message)
    ip := getLocalIP()
    hostname, _ := os.Hostname()
    msgWithIP := fmt.Sprintf("%s\nHost: %s\nIP: %s", message, hostname, ip)

    alertTimes := lastAlert[hash]
    priority := "1"
if len(alertTimes) >= 2 && now.Sub(alertTimes[0]) >= 15*time.Minute {
    priority = "5" 
} else {
    priority = "3" // Vždy 1 pro první 2 alerty
}
    // Pokud poslední alert byl poslán před méně než ALERT_INTERVAL, neposílej znovu
    if len(alertTimes) > 0 && now.Sub(alertTimes[len(alertTimes)-1]) < cfg.AlertInterval {
        return
    }

    req, _ := http.NewRequest("POST", cfg.NtfyServer, strings.NewReader(msgWithIP))
    req.Header.Set("Priority", priority)

    client := &http.Client{Timeout: 5 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        log.Printf("CHYBA odeslání alertu: %v", err)
        return
    }
    defer resp.Body.Close()

    // Ulož čas alertu, uchovávej max 3 časy
    lastAlert[hash] = append(alertTimes, now)
    if len(lastAlert[hash]) > 3 {
        lastAlert[hash] = lastAlert[hash][1:]
    }

log.Printf("ALERT (priority %s): %s | ntfy server: %s", priority, msgWithIP, cfg.NtfyServer)
}


func installService() {
	exe, _ := os.Executable()
	unit := fmt.Sprintf(`[Unit]
Description=Monitor SLAMA Service

[Service]
ExecStart=%s
Restart=always

[Install]
WantedBy=multi-user.target`, exe)

	os.WriteFile("/etc/systemd/system/monitor-slama.service", []byte(unit), 0644)
	exec.Command("systemctl", "daemon-reload").Run()
	exec.Command("systemctl", "enable", "monitor-slama").Run()
}

func init() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "install":
			installService()
			fmt.Println("Instalace dokončena")
			os.Exit(0)
		case "check":
			checkRequirements()
			os.Exit(0)
		}
	}
}

