//
//  ViewController.m
//  quicStreamDemo
//
//  Created by Mengqiang Jia on 2023/4/20.
//

#import "ViewController.h"
#import <Network/Network.h>
//@import Network;

@interface ViewController ()

@property (nonatomic, strong)nw_connection_t connection;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)startQuicClient {
    nw_parameters_t quicParameters = nw_parameters_create_quic(^(nw_protocol_options_t  _Nonnull options) {
        // TLS 设置
        sec_protocol_options_t secOptions = nw_quic_copy_sec_protocol_options(options);
        sec_protocol_options_set_tls_server_name(secOptions, "example.com");// 将 "example.com" 替换为您的服务器证书的主机名
        sec_protocol_options_set_verify_block(secOptions, ^(sec_protocol_metadata_t  _Nonnull metadata, sec_trust_t  _Nonnull trust_ref, sec_protocol_verify_complete_t  _Nonnull complete) {
            // 验证证书
            bool isCertificateValid = false;
            // 检查证书链、签名、颁发者和有效期
            CFErrorRef error = NULL;
            isCertificateValid = SecTrustEvaluateWithError((__bridge SecTrustRef)trust_ref, &error);
            if (error) {
                CFRelease(error);
            }
            // 检查证书主机名
            if (isCertificateValid) {
                // 获取服务器证书链
                CFArrayRef certChain = SecTrustCopyCertificateChain((__bridge SecTrustRef)trust_ref);
                if (certChain != NULL) {
                    // 获取服务器证书
                    SecCertificateRef serverCert = (SecCertificateRef)CFArrayGetValueAtIndex(certChain, 0);
                    if (serverCert != NULL) {
                        // 获取证书中的公共名 (CN)
                        CFStringRef commonName = NULL;
                        SecCertificateCopyCommonName(serverCert, &commonName);

                        // 检查公共名是否与预期的主机名匹配
                        if (commonName != NULL) {
                            NSString *serverCommonName = (__bridge NSString *)commonName;
                            isCertificateValid = [serverCommonName isEqualToString:@"example.com"]; // 将 "example.com" 替换为您期望的服务器主机名
                            CFRelease(commonName);
                        } else {
                            isCertificateValid = false;
                        }
                    } else {
                        isCertificateValid = false;
                    }
                    CFRelease(certChain);
                } else {
                    isCertificateValid = false;
                }
            }

            // 完成证书验证
            complete(isCertificateValid);
        }, dispatch_get_main_queue());
    });
    
    nw_endpoint_t endpoint = nw_endpoint_create_host("localhost", "1234");
    self.connection = nw_connection_create(endpoint, quicParameters);
    
    nw_connection_set_queue(_connection, dispatch_get_main_queue());
    
    nw_connection_set_state_changed_handler(_connection, ^(nw_connection_state_t state, nw_error_t error) {
        
        switch (state) {
            case nw_connection_state_invalid:
                break;
            case nw_connection_state_waiting:
                break;
            case nw_connection_state_preparing:
                break;
            case nw_connection_state_ready:
                [self receiveData];
                break;
            case nw_connection_state_failed:
                break;
            case nw_connection_state_cancelled:
                break;
            default:
                break;
        }
        
    });
    
    nw_connection_start(_connection);
}
- (void)receiveData {
    NSMutableData *receivedData = [NSMutableData data];
    nw_connection_receive_message(self.connection, ^(dispatch_data_t  _Nullable content, nw_content_context_t  _Nullable context, bool is_complete, nw_error_t  _Nullable error) {
        if (error) {
            NSLog(@"Error sending data : %@",[error description]);
        }
        if (context) {
            [receivedData appendData:(NSData *)content];
            if (is_complete) {
                NSString *receivedMessage = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
                NSLog(@"Received data from server: %@", receivedMessage);
            }
        }
    });
}

- (void)sendText:(NSString* )message {
    const void *msgData = [[message dataUsingEncoding:NSUTF8StringEncoding] bytes];
    dispatch_data_t dataToSend = dispatch_data_create(msgData, strlen(msgData), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    nw_connection_send(self.connection, dataToSend, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t  _Nullable error) {
        if (error) {
            NSLog(@"Error sending data : %@", error);
        }
        NSLog(@"Data sent successfully!");
    });
}

@end
