import argparse
import logging
import os
import socket
import threading
import datetime
import dns.resolver
import subprocess
import re

## Usage:
# python ports.py -listener_ports '801,6443,443' -remote_ip '10.220.31.107' -remote_ports '80,6443,443' -log_path '/tmp/logfile.log' -gateway '10.220.31.126' -ntp_server 'time1.oc.vmware.com' -vcenter_fqdn 'vc01.h2o-4-14542.h2o.vmware.com' -dns_server '10.220.136.2'
# python ports.py -listener_ports '801,6443,443' -remote_ip '10.220.31.107' -remote_ports '80,6443,443' -log_path '/tmp/logfile.log' -listener_ports_udp '100,101' -remote_ports_udp '100,101'
# python ports.py -listener_ports '801,6443,443' -remote_ip '10.220.31.107' -remote_ports '80,6443,443' -log_path '/tmp/logfile.log'
# python ports.py -listener_ports '801,6443,443' -log_path '/tmp/logfile.log'

## On Management Network:
# export ports_to_serve_mgt='80, 443, 22, 5000, 6443, 8443, 8888, 9000, 9001, 9443'
# export ports_mgt_to_w0='443, 22, 6443, 9443'
# export ports_mgt_to_w1='443, 22, 6443'
# export MGT_GW=''
# export NTP_IP=''
# export vCenterAddress=''
# export DNS_IP=''
# export W0_IP=''
# export W1_IP=''
# systemctl stop iptables && systemctl stop arcas && systemctl stop nginx
# python ports.py -listener_ports $ports_to_serve_mgt -log_path '/tmp/logfile.log' &
# python ports.py -log_path '/tmp/logfile.log' -gateway $MGT_GW -ntp_server $NTP_IP -vcenter_fqdn $vCenterAddress -dns_server $DNS_IP
# python ports.py -remote_ip $W0_IP -remote_ports $ports_mgt_to_w0 -log_path '/tmp/logfile.log'
# python ports.py -remote_ip $W1_IP -remote_ports $ports_mgt_to_w1 -log_path '/tmp/logfile.log'


## On Workload0 Network:
# export ports_to_serve_w0='80, 443, 22, 6443, 9443, 30001, 31010, 61001, 61010'
# export ports_w0_to_mgt='443, 22, 6443, 9443, 9000, 9001, 8443'
# export ports_w0_to_w1='443, 6443, 2112, 2113'
# export W0_GW=''
# export NTP_IP=''
# export vCenterAddress=''
# export DNS_IP=''
# export MGT_IP=''
# export W1_IP=''
# systemctl stop iptables && systemctl stop arcas && systemctl stop nginx
# python ports.py -listener_ports $ports_to_serve_w0 -log_path '/tmp/logfile.log' &
# python ports.py -log_path '/tmp/logfile.log' -gateway $W0_GW -ntp_server $NTP_IP -vcenter_fqdn $vCenterAddress -dns_server $DNS_IP
# python ports.py -remote_ip $MGT_IP -remote_ports $ports_w0_to_mgt -log_path '/tmp/logfile.log'
# python ports.py -remote_ip $W1_IP -remote_ports $ports_w0_to_w1 -log_path '/tmp/logfile.log'

## On Workload1 Network:
# export ports_to_serve_w1='80, 443, 22, 6443, 2112, 2113, 8443, 8080'
# export ports_w1_to_mgt='6443, 8443'
# export ports_w1_to_w0='80, 443, 6443, 30001, 31010, 61001, 61010'
# export W1_GW=''
# export NTP_IP=''
# export vCenterAddress=''
# export DNS_IP=''
# export MGT_IP=''
# export W0_IP=''
# systemctl stop iptables && systemctl stop arcas && systemctl stop nginx
# python ports.py -listener_ports $ports_to_serve_w1 -log_path '/tmp/logfile.log' &
# python ports.py -log_path '/tmp/logfile.log' -gateway $W1_GW -ntp_server $NTP_IP -vcenter_fqdn $vCenterAddress -dns_server $DNS_IP
# python ports.py -remote_ip $MGT_IP -remote_ports $ports_w1_to_mgt -log_path '/tmp/logfile.log'
# python ports.py -remote_ip $W0_IP -remote_ports $ports_w1_to_w0 -log_path '/tmp/logfile.log'

## On Client/RDP/VPN Network:
## with powershell
# Test-NetConnection $MGT_IP -Port 443
# Test-NetConnection $MGT_IP -Port 8888
# Test-NetConnection $MGT_IP -Port 5000
# Test-NetConnection $MGT_IP -Port 9443
# Test-NetConnection $W1_IP -Port 443
# Test-NetConnection $W1_IP -Port 6443
# Test-NetConnection $W1_IP -Port 80
# Test-NetConnection $W1_IP -Port 8080
# Test-NetConnection $W1_IP -Port 8443


# Configure logging
def configure_logging(log_path):
    logger = logging.getLogger('')
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

    # Create a file handler
    file_handler = logging.FileHandler(log_path)
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    # Create a console handler (if not already created)
    if not any(isinstance(handler, logging.StreamHandler) for handler in logger.handlers):
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

# Define the function to create TCP listeners
def create_tcp_listener(port):
    try:
        # Create a TCP socket object
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        # Bind the socket to a specific port
        listener.bind(('0.0.0.0', port))

        # Listen for incoming TCP connections
        listener.listen(1)

        logging.info(f"TCP Listener created on port {port}")

        while True:
            # Accept incoming TCP connections
            client_socket, client_address = listener.accept()
            logging.info(f"Incoming TCP connection from: {client_address[0]}:{client_address[1]}")
            client_socket.close()

    except Exception as e:
        logging.error(f"Failed to create TCP Listener on port {port}: {str(e)}")
    finally:
        # Close the listener socket
        listener.close()

# Define the function to create UDP listeners
def create_udp_listener(port):
    try:
        # Create a UDP socket object
        listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        # Bind the socket to a specific port
        listener.bind(('0.0.0.0', port))

        logging.info(f"UDP Listener created on port {port}")

        while True:
            # Receive UDP packets
            data, addr = listener.recvfrom(1024)
            logging.info(f"Incoming UDP packet from: {addr[0]}:{addr[1]}")

            # Respond with a specific message to indicate that the port is open
            listener.sendto(b"UDP Port is open", addr)

    except Exception as e:
        logging.error(f"Failed to create UDP Listener on port {port}: {str(e)}")
    finally:
        # Close the listener socket
        listener.close()

# Define the function to test TCP port connectivity to the remote IP address
def test_tcp_connectivity(port, remote_ip):
    try:
        # Create a TCP socket object
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)  # Set a timeout for the connection attempt

        # Connect to the remote IP address and port
        sock.connect((remote_ip, port))

        logging.info(f"TCP Port {port} is open and accessible on {remote_ip}")
    except Exception as e:
        logging.error(f"TCP Port {port} is not accessible on {remote_ip}: {str(e)}")
    finally:
        # Close the socket
        sock.close()

# Define the function to test UDP port connectivity to the remote IP address
def test_udp_connectivity(port, remote_ip):
    try:
        # Create a UDP socket object
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(2)  # Set a timeout for the response

        # Send a custom payload to the remote IP address and port
        sock.sendto(b"UDP Port Test", (remote_ip, port))

        # Receive the response (if any)
        try:
            data, addr = sock.recvfrom(1024)
            if data == b"UDP Port is open":
                logging.info(f"UDP Port {port} is open and accessible on {remote_ip}")
            else:
                logging.error(f"UDP Port {port} is closed or not accessible on {remote_ip}")
        except socket.timeout:
            logging.error(f"UDP Port {port} is closed or not accessible on {remote_ip}")

    except Exception as e:
        logging.error(f"UDP Port {port} is not accessible on {remote_ip}: {str(e)}")
    finally:
        # Close the socket
        sock.close()

# Define the function to test gateway connectivity using ICMP (ping)
def test_gateway_connectivity(gateway):
    try:
        # Run the ping command to test the gateway connectivity
        ping_process = subprocess.Popen(['ping', '-c', '3', gateway], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        ping_output, _ = ping_process.communicate()

        # Check the return code of the ping command
        if ping_process.returncode == 0:
            logging.info(f"Gateway {gateway} is reachable")
        else:
            logging.error(f"Gateway {gateway} is not reachable")
    except Exception as e:
        logging.error(f"Failed to test gateway {gateway} connectivity: {str(e)}")

# Define the function to test connectivity to the NTP server
def test_ntp_server_connectivity(ntp_server):
    try:
        # Get the current system time
        system_time = datetime.datetime.now()
        logging.info(f"System Time: {system_time}")

        # Run the ntpdate command to fetch the time from the NTP server
        ntpdate_process = subprocess.Popen(['ntpdate', '-q', ntp_server], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        ntpdate_output, _ = ntpdate_process.communicate()

        # Check the return code of the ntpdate command
        if ntpdate_process.returncode == 0:
            logging.info(f"NTP Server {ntp_server} is reachable")
        else:
            logging.error(f"NTP Server {ntp_server} is not reachable")
    except Exception as e:
        logging.error(f"Failed to test NTP server {ntp_server} connectivity: {str(e)}")



# Define the function to test connectivity to the vCenter FQDN on port 443
def test_vcenter_connectivity(vcenter_fqdn):
    try:
        # Create a TCP socket object
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)  # Set a timeout for the connection attempt

        # Resolve the vCenter FQDN to get the IP address
        ip_address = socket.gethostbyname(vcenter_fqdn)

        # Connect to the vCenter IP address on port 443
        sock.connect((ip_address, 443))

        logging.info(f"vCenter {vcenter_fqdn} is reachable at IP address {ip_address}")
    except Exception as e:
        logging.error(f"vCenter {vcenter_fqdn} is not reachable: {str(e)}")
    finally:
        # Close the socket
        sock.close()

# Define the function to test DNS resolution of the vCenter FQDN using the DNS server
def test_dns_resolution(vcenter_fqdn, dns_server):
    try:
        # Create a DNS resolver object using the specified DNS server
        resolver = dns.resolver.Resolver()
        resolver.nameservers = [dns_server]

        # Resolve the IP address of the vCenter FQDN
        answers = resolver.query(vcenter_fqdn)

        for answer in answers:
            logging.info(f"DNS resolution for {vcenter_fqdn}: {answer.to_text()}")
    except Exception as e:
        logging.error(f"Failed to resolve DNS for {vcenter_fqdn} using DNS server {dns_server}: {str(e)}")

# Parse command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-listener_ports', type=str, help='TCP ports for creating listeners')
parser.add_argument('-listener_ports_udp', type=str, help='UDP ports for creating listeners')
parser.add_argument('-remote_ip', type=str, help='Remote IP address to test TCP port connectivity')
parser.add_argument('-remote_ports', type=str, help='TCP ports to test on the remote IP address')
parser.add_argument('-remote_ports_udp', type=str, help='UDP ports to test on the remote IP address')
parser.add_argument('-gateway', type=str, help='Gateway IP address to test connectivity')
parser.add_argument('-ntp_server', type=str, help='NTP server IP address to test connectivity')
parser.add_argument('-vcenter_fqdn', type=str, help='vCenter FQDN to test connectivity')
parser.add_argument('-dns_server', type=str, help='DNS server IP address to test DNS resolution')
parser.add_argument('-log_path', type=str, default='port_connectivity.log', help='Path to the log file')
args = parser.parse_args()

# Configure logging to use the specified log path
log_path = os.path.abspath(args.log_path)
configure_logging(log_path)

# Create TCP listener threads if listener_ports are specified
if args.listener_ports:
    listener_ports = [int(port) for port in args.listener_ports.split(',')]
    tcp_listener_threads = []
    for port in listener_ports:
        thread = threading.Thread(target=create_tcp_listener, args=(port,))
        thread.start()
        tcp_listener_threads.append(thread)

# Create UDP listener threads if listener_ports_udp are specified
if args.listener_ports_udp:
    listener_ports_udp = [int(port) for port in args.listener_ports_udp.split(',')]
    udp_listener_threads = []
    for port in listener_ports_udp:
        thread = threading.Thread(target=create_udp_listener, args=(port,))
        thread.start()
        udp_listener_threads.append(thread)

# Test TCP port connectivity to the remote IP address if both remote_ip and remote_ports are provided
if args.remote_ip and args.remote_ports:
    remote_ip = args.remote_ip
    remote_ports = [int(port) for port in args.remote_ports.split(',')]
    for port in remote_ports:
        test_tcp_connectivity(port, remote_ip)

# Test UDP port connectivity to the remote IP address if both remote_ip and remote_ports_udp are provided
if args.remote_ip and args.remote_ports_udp:
    remote_ip = args.remote_ip
    remote_ports_udp = [int(port) for port in args.remote_ports_udp.split(',')]
    for port in remote_ports_udp:
        test_udp_connectivity(port, remote_ip)

# Test connectivity to the gateway if the gateway parameter is provided
if args.gateway:
    test_gateway_connectivity(args.gateway)

# Test connectivity to the NTP server if the ntp_server parameter is provided
if args.ntp_server:
    test_ntp_server_connectivity(args.ntp_server)

# Test connectivity to the vCenter FQDN if the vcenter_fqdn parameter is provided
if args.vcenter_fqdn:
    test_vcenter_connectivity(args.vcenter_fqdn)

# Test DNS resolution of the vCenter FQDN if the vcenter_fqdn and dns_server parameters are provided
if args.vcenter_fqdn and args.dns_server:
    test_dns_resolution(args.vcenter_fqdn, args.dns_server)

# Wait for all TCP listener threads to finish
if args.listener_ports:
    for thread in tcp_listener_threads:
        thread.join()

# Wait for all UDP listener threads to finish
if args.listener_ports_udp:
    for thread in udp_listener_threads:
        thread.join()
