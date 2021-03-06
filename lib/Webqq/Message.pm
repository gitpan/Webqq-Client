package Webqq::Message;
use Webqq::Message::Face;
use JSON;
use Encode;
use Webqq::Client::Util qw(console_stderr console);
use Scalar::Util qw(blessed);
sub reply_message{
    my $client = shift;
    my $msg = shift;
    my $content = shift;
    unless(blessed($msg)){
        console_stderr "输入的msg数据非法\n";
        return 0;
    }
    if($msg->{type} eq 'message'){
        $client->send_message(
            $client->create_msg(to_uin=>$msg->{from_uin},content=>$content)
        );
    }
    elsif($msg->{type} eq 'group_message'){
        $client->send_group_message(
            $client->create_group_msg( 
                to_uin=>$msg->{from_uin},    
                content=>$content,
                group_code=>$msg->{group_code}  
            )  
        ); 
    }
    elsif($msg->{type} eq 'sess_message'){
        $client->send_sess_message(
            $client->create_sess_msg(
                group_sig   =>  $client->_get_group_sig($msg->{gid},$msg->{from_uin},$msg->{service_type}),
                to_uin      =>  $msg->{from_uin},
                content     =>  $content,
                service_type =>  $msg->{service_type},
                group_code  => $msg->{group_code},
            )
        );
    }
    
}
sub create_sess_msg{
    my $client = shift;
    return $client->_create_msg(@_,type=>'sess_message');
}
sub create_group_msg{   
    my $client = shift;
    return $client->_create_msg(@_,type=>'group_message');
}
sub create_msg{
    my $client = shift;
    return $client->_create_msg(@_,type=>'message');
}
sub _create_msg {
    my $client = shift;
    my %p = @_;
    $p{content} =~s/\r|\n/\n/g;
    my %msg = (
        type        => $p{type},
        msg_id      => $p{msg_id} || ++$client->{qq_param}{send_msg_id},
        from_uin    => $p{from_uin} || $client->{qq_param}{from_uin},
        to_uin      => $p{to_uin},
        content     => $p{content},
        msg_class   => "send",
        msg_time    => time,
        cb          => $p{cb},
        ttl         => 5,
        allow_plugin => 1,
    );
    if($p{type} eq 'sess_message'){
        if(defined $p{service_type} and defined $p{group_sig}){
            $msg{service_type} = $p{service_type};
            $msg{group_sig} = $p{group_sig};
            $msg{group_code} = $p{group_code};
        }
        elsif($p{group_code}){
            $msg{group_code} = $p{group_code};
            $msg{group_sig} = $client->_get_group_sig(
                $client->search_group($p{group_code})->{gid},
                $p{to_uin},
                0,   
            );
            $msg{service_type} = 0;
        }
        else{
            console "create_sess_msg()必须设置group_code参数\n";
            return ;
        }
    }
    elsif($p{type} eq 'group_message'){
        $msg{group_code} = $p{group_code}||$client->get_group_code_from_gid($p{to_uin});
        $msg{send_uin} = $msg{from_uin};
    }   
    my $msg_pkg = "\u$p{type}::Send"; 
    $msg_pkg=~s/_(.)/\u$1/g;
    return $client->_mk_ro_accessors(\%msg,$msg_pkg);
     
}

sub _load_extra_accessor {
    my $client = shift;
    *Webqq::Message::GroupMessage::Recv::group_name = sub{
        my $msg = shift;
        my $g = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef ;
    };
    *Webqq::Message::GroupMessage::Recv::from_gname = sub{
        my $msg = shift;
        my $g = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef ;
    };
    *Webqq::Message::GroupMessage::Recv::from_qq = sub{
        my $msg = shift;
        return $client->get_qq_from_uin($msg->{send_uin});
    };
    *Webqq::Message::GroupMessage::Recv::from_nick = sub{
        my $msg = shift;
        my $m = $client->search_member_in_group($msg->{group_code},$msg->{send_uin});
        return defined $m?$m->{nick}:undef;
    };
    *Webqq::Message::GroupMessage::Recv::from_card = sub{
        my $msg = shift;
        my $m = $client->search_member_in_group($msg->{group_code},$msg->{send_uin});
        return defined $m?$m->{card}:undef;
    };
    *Webqq::Message::GroupMessage::Recv::from_city = sub{
        my $msg = shift;
        my $m = $client->search_member_in_group($msg->{group_code},$msg->{send_uin});
        return defined $m?$m->{city}:undef;
    };

    *Webqq::Message::GroupMessage::Send::group_name = sub{
        my $msg = shift;
        my $g  = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef;
    };
    *Webqq::Message::GroupMessage::Send::to_gname = sub{
        my $msg = shift;
        my $g  = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef;
    };
    *Webqq::Message::GroupMessage::Send::from_qq = sub{
        return $client->{qq_param}{qq};
    };
    *Webqq::Message::GroupMessage::Send::from_nick = sub{
        return "我";
    };


    *Webqq::Message::SessMessage::Recv::from_nick = sub{
        my $msg = shift;
        my $m = $client->search_member_in_group($msg->{group_code},$msg->{from_uin});
        return defined $m?$m->{nick}:undef;
    };
    *Webqq::Message::SessMessage::Recv::from_qq = sub {
        my $msg = shift;
        return $msg->{ruin};
    };
    *Webqq::Message::SessMessage::Recv::to_nick = sub{
        return "我";
    };
    *Webqq::Message::SessMessage::Recv::to_qq = sub {
        return $client->{qq_param}{qq};
    };

    *Webqq::Message::SessMessage::Recv::group_name = sub {
        my $msg = shift;
        my $g = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef;
    };
    *Webqq::Message::SessMessage::Recv::from_group = sub {
        my $msg = shift;
        my $g = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef;
    };

    *Webqq::Message::SessMessage::Send::from_nick = sub{
        return "我";
    };
    *Webqq::Message::SessMessage::Send::from_qq = sub {
        return $client->{qq_param}{qq};
    };
    *Webqq::Message::SessMessage::Send::to_nick = sub{
        my $msg = shift;
        my $m = $client->search_member_in_group($msg->{group_code},$msg->{to_uin});
        return defined $m?$m->{nick}:undef;
    };
    *Webqq::Message::SessMessage::Send::to_qq = sub{
        my $msg = shift;
        return $client->get_qq_from_uin($msg->{to_uin});
    };
    *Webqq::Message::SessMessage::Send::group_name = sub{
        my $msg = shift;
        my $g = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef;
    };
    *Webqq::Message::SessMessage::Send::to_group = sub{
        my $msg = shift;
        my $g = $client->search_group($msg->{group_code});
        return defined $g?$g->{name}:undef;
    }; 


    *Webqq::Message::Message::Recv::from_nick = sub{
        my $msg = shift;
        my $f = $client->search_friend($msg->{from_uin});
        return defined $f?$f->{nick}:undef;
    };
    *Webqq::Message::Message::Recv::from_qq = sub{
        my $msg = shift;
        return $client->get_qq_from_uin($msg->{from_uin});
    };
    *Webqq::Message::Message::Recv::from_markname = sub{
        my $msg = shift;
        my $f = $client->search_friend($msg->{from_uin});
        return defined $f?$f->{markname}:undef;
    };
    *Webqq::Message::Message::Recv::from_categories = sub {
        my $msg = shift;    
        my $f = $client->search_friend($msg->{from_uin});
        return defined $f?$f->{categories}:undef;
    };

    *Webqq::Message::Message::Recv::from_city = sub {
        my $msg = shift;
        my $f = $client->search_friend($msg->{from_uin});
        return defined $f?$f->{city}:undef;
    };
    
    *Webqq::Message::Message::Recv::to_nick = sub{
        return "我";
    };
    *Webqq::Message::Message::Recv::to_qq = sub {
        return $client->{qq_param}{qq};
    };


    *Webqq::Message::Message::Send::from_nick = sub{
        return "我";
    };
    *Webqq::Message::Message::Send::from_qq = sub{
        return $client->{qq_param}{qq};
    };
    *Webqq::Message::Message::Send::to_nick = sub{
        my $msg = shift;
        my $f = $client->search_friend($msg->{to_uin});
        return defined $f?$f->{nick}:undef;
    };
    *Webqq::Message::Message::Send::to_qq = sub{
        my $msg = shift;
        return $client->get_qq_from_uin($msg->{to_uin});
    };
    *Webqq::Message::Message::Send::to_markname = sub{
        my $msg = shift;
        my $f = $client->search_friend($msg->{to_uin});
        return defined $f?$f->{markname}:undef;
    };
    *Webqq::Message::Message::Send::to_categories = sub{
        my $msg = shift;
        my $f = $client->search_friend($msg->{to_uin});
        return defined $f?$f->{categories}:undef;
    };

}

sub _mk_ro_accessors {
    my $client = shift;
    my $msg =shift;    
    my $msg_pkg = shift;
    no strict 'refs';
    for my $field (keys %$msg){
        *{"Webqq::Message::${msg_pkg}::$field"} = sub{
            my $self = shift;
            my $pkg = ref $self;
            die "the value of \"$field\" in $pkg is read-only\n" if @_!=0;
            return $self->{$field};
        };
    }
          
    $msg = bless $msg,"Webqq::Message::$msg_pkg";
    return $msg;
}

sub parse_send_status_msg{
    my $client = shift;
    my ($json_txt) = @_;
    my $json     = undef;
    eval{$json = JSON->new->utf8->decode($json_txt)};
    console_stderr "解析消息失败: $@ 对应的消息内容为: $json_txt\n" if $@ and $client->{debug};
    if(ref $json eq 'HASH' and $json->{retcode}==0){
        return {is_success=>1,status=>"发送成功"}; 
    }
    else{
        return {is_success=>0,status=>"发送失败"};
    }
}
#消息的后期处理
sub msg_put{   
    my $client = shift;
    my $msg = shift;
    $msg->{raw_content} = [];
    my $msg_content;
    shift @{ $msg->{content} };
    for my $c (@{ $msg->{content} }){
        if(ref $c eq 'ARRAY'){
            if($c->[0] eq 'cface' or $c->[0] eq 'offpic'){
                push @{$msg->{raw_content}},{
                    type    =>  'cface',
                    content =>  '[图片]',
                    name    =>  $c->[1]{name},
                    file_id =>  $c->[1]{file_id},
                    key     =>  $c->[1]{key},
                    server  =>  $c->[1]{server},
                };
                $c=decode("utf8","[图片]");
            }
            elsif($c->[0] eq 'face'){
                push @{$msg->{raw_content}},{
                    type    =>  'face',
                    content =>  face_to_txt($c),
                    id      =>  $c->[1],
                }; 
                $c=decode("utf8",face_to_txt($c));
            }
            else{
                push @{$msg->{raw_content}},{
                    type    =>  'unknown',
                    content =>  '[未识别内容]',
                };
                $c = decode("utf8","[未识别内容]");
            }
        }
        elsif($c eq " "){
            next;
        }
        else{
            $c=~s/ $//;   
            #{"retcode":0,"result":[{"poll_type":"group_message","value":{"msg_id":538,"from_uin":2859929324,"to_uin":3072574066,"msg_id2":545490,"msg_type":43,"reply_ip":182424361,"group_code":2904892801,"send_uin":1951767953,"seq":3024,"time":1418955773,"info_seq":390179723,"content":[["font",{"size":12,"color":"000000","style":[0,0,0],"name":"\u5FAE\u8F6F\u96C5\u9ED1"}],"[\u50BB\u7B11]\u0001 "]}}]}
            #if($c=~/\[[^\[\]]+?\]\x{01}/)
            push @{$msg->{raw_content}},{
                type    =>  'txt',
                content =>  encode("utf8",$c),
            };
        }
        $msg_content .= $c;
    }
    $msg->{content} = $msg_content;
    #将整个hash从unicode转为UTF8编码
    $msg->{$_} = encode("utf8",$msg->{$_} ) for grep {$_ ne 'raw_content'}  keys %$msg;
    $msg->{content}=~s/\r|\n/\n/g;
    if($msg->{content}=~/\(\d+\) 被管理员禁言\d+(分钟|小时|天)$/ or $msg->{content}=~/\(\d+\) 被管理员解除禁言$/){
        $msg->{type} = "sys_g_msg";
        return;
    }
    my $msg_pkg = "\u$msg->{type}::Recv"; $msg_pkg=~s/_(.)/\u$1/g;
    $msg = $client->_mk_ro_accessors($msg,$msg_pkg) ;
    $client->{receive_message_queue}->put($msg);
}

sub parse_receive_msg{
    my $client = shift;
    my ($json_txt) = @_;  
    my $json     = undef;
    eval{$json = JSON->new->utf8->decode($json_txt)};
    console_stderr "解析消息失败: $@ 对应的消息内容为: $json_txt\n" if $@ and $client->{debug};
    if($json){
        #一个普通的消息
        if($json->{retcode}==0){
            for my $m (@{ $json->{result} }){
                #收到群临时消息
                if($m->{poll_type} eq 'sess_message'){
                    #service_type =0 表示群临时消息，1 表示讨论组临时消息
                    return if $m->{value}{service_type} != 0;
                    my $msg = {
                        type        =>  'sess_message',
                        msg_id      =>  $m->{value}{msg_id},
                        from_uin    =>  $m->{value}{from_uin},
                        to_uin      =>  $m->{value}{to_uin},
                        msg_time    =>  $m->{value}{'time'},
                        content     =>  $m->{value}{content},
                        service_type=>  $m->{value}{service_type},
                        ruin        =>  $m->{value}{ruin},
                        gid         =>  $m->{value}{id},
                        group_code  =>  $client->get_group_code_from_gid($m->{value}{id}),
                        msg_class   =>  "recv",
                        ttl         =>  5,  
                        allow_plugin => 1,
                    };
                    $client->msg_put($msg);
                }
                #收到的消息是普通消息
                elsif($m->{poll_type} eq 'message'){
                    my $msg = {
                        type        =>  'message',
                        msg_id      =>  $m->{value}{msg_id},
                        from_uin    =>  $m->{value}{from_uin},
                        to_uin      =>  $m->{value}{to_uin},
                        msg_time    =>  $m->{value}{'time'},
                        content     =>  $m->{value}{content},
                        msg_class   =>  "recv",
                        ttl         =>  5,
                        allow_plugin => 1,
                    };
                    $client->msg_put($msg);
                }   
                #收到的消息是群消息
                elsif($m->{poll_type} eq 'group_message'){
                    my $msg = {
                        type        =>  'group_message',
                        msg_id      =>  $m->{value}{msg_id},
                        from_uin    =>  $m->{value}{from_uin},
                        to_uin      =>  $m->{value}{to_uin},
                        msg_time    =>  $m->{value}{'time'},
                        content     =>  $m->{value}{content},
                        send_uin    =>  $m->{value}{send_uin},
                        group_code  =>  $m->{value}{group_code}, 
                        msg_class   =>  "recv",
                        ttl         =>  5,
                        allow_plugin => 1,
                    };
                    $client->msg_put($msg);
                }
                #收到系统消息
                elsif($m->{poll_type} eq 'sys_g_msg'){
                    
                }
                #收到强制下线消息
                elsif($m->{poll_type} eq 'kick_message'){
                    if($m->{value}{show_reason} ==1){
                        my $reason = encode("utf8",$m->{value}{reason});
                        console "$reason\n" ;
                        exit;
                    }
                    else {console "您已被迫下线\n" }
                    exit;                    
                }
                #还未识别和处理的消息
                else{

                }  
            }
        }
        #可以忽略的消息，暂时不做任何处理
        elsif($json->{retcode} == 102){}
        #更新客户端ptwebqq值
        elsif($json->{retcode} == 116){$client->{qq_param}{ptwebqq} = $json->{p};}
        #未重新登录
        elsif($json->{retcode} ==100 or $json->{retcode} ==103){
            console_stderr "需要重新登录\n";
            $client->relogin();
        }
        #重新连接失败
        elsif($json->{retcode} ==120 or $json->{retcode} ==121 ){
            console_stderr "重新连接失败\n";
            $client->relogin();
        }
        #其他未知消息
        else{console_stderr "读取到未知消息: $json_txt\n";}
    } 
}
1;

