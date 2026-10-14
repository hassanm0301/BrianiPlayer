#!/usr/bin/env python3
"""Owned generated-byte HTTP/peer recorder and authoritative fixture-name DNS."""
import argparse, ipaddress, json, pathlib, re, socket, socketserver, struct, threading, time

def run(root, ports, dns_port):
    lock=threading.Lock()
    def state(): return json.loads((root/'state.json').read_text())
    def event(value):
        with lock, (root/'events.jsonl').open('a') as output: output.write(json.dumps(value)+'\n')
    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            self.request.settimeout(3); data=bytearray()
            try:
                while len(data)<16384:
                    chunk=self.request.recv(4096)
                    if not chunk:return
                    data.extend(chunk)
                    if data[0] not in (ord('G'),ord('H')):
                        event({'type':'peer','port':self.server.server_address[1]});return
                    if b'\r\n\r\n' in data:break
                lines=bytes(data).split(b'\r\n'); method,path,_=lines[0].decode('ascii').split(' ',2);path=path.split('?',1)[0]
                event({'type':'http','port':self.server.server_address[1],'method':method,'path':path})
                redirect=next((value for prefix,value in state().get('redirects',{}).items() if path.startswith(prefix)),None)
                if redirect:body=b'';status='302 Found';headers=['Location: '+redirect]
                elif path.startswith('/announce'):body=b'd8:intervali5e5:peers0:e';status='200 OK';headers=['Content-Type: application/x-bittorrent']
                else:
                    body=bytes(16384);status='200 OK';headers=['Content-Type: application/octet-stream']
                    for line in lines[1:]:
                        match=re.fullmatch(rb'range: bytes=(\d+)-(\d*)',line,re.I)
                        if match:
                            start=int(match[1]);end=min(int(match[2]) if match[2] else len(body)-1,len(body)-1)
                            if start>=len(body) or end<start:return
                            headers.append(f'Content-Range: bytes {start}-{end}/{len(body)}');body=body[start:end+1];status='206 Partial Content'
                header='HTTP/1.1 '+status+'\r\n'+'\r\n'.join(headers+[f'Content-Length: {len(body)}','Connection: close'])+'\r\n\r\n'
                self.request.sendall(header.encode('ascii')+(body if method!='HEAD' else b''))
            except (OSError,ValueError):return
    class Tcp(socketserver.ThreadingTCPServer):
        allow_reuse_address=True;daemon_threads=True
    for port in ports:
        server=Tcp(('0.0.0.0',port),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
    if dns_port:
        udp=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
        udp.bind(('0.0.0.0',dns_port))
        def dns():
            with udp:
                while True:
                    data,address=udp.recvfrom(4096)
                    try:
                        if len(data)<12 or struct.unpack('!H',data[4:6])[0]!=1:continue
                        offset=12;labels=[]
                        while data[offset]:
                            length=data[offset];offset+=1
                            if length>63:raise ValueError('nonliteral fixture question')
                            labels.append(data[offset:offset+length].decode('ascii'));offset+=length
                        offset+=1;end=offset+4;qtype,qclass=struct.unpack('!HH',data[offset:end]);name='.'.join(labels).lower()
                        answer=state().get('dnsAnswers',{}).get(name) if qtype==1 and qclass==1 else None
                        event({'type':'dns','name':name,'qtype':qtype,'answer':answer})
                        record=b'\xc0\x0c'+struct.pack('!HHIH',1,1,0,4)+ipaddress.IPv4Address(answer).packed if answer else b''
                        header=data[:2]+struct.pack('!HHHHH',0x8180 if answer or qtype==28 else 0x8183,1,int(bool(answer)),0,0)
                        udp.sendto(header+data[12:end]+record,address)
                    except (IndexError,ValueError,struct.error):continue
        threading.Thread(target=dns,daemon=True).start()
    (root/'ready').write_text('ready\n')
    while True:time.sleep(1)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('--ports',required=True);p.add_argument('--dns-port',type=int,default=0);a=p.parse_args();run(a.root,[int(x) for x in a.ports.split(',')],a.dns_port)
