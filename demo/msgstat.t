#!/usr/bin/perl
use lib "../src";
use Storable;
my $msgstat=(-e "/tmp/webqq/data/msgstat")?retrieve("/tmp/webqq/data/msgstat"):{};
#use Data::Dumper;
#print Dumper $msgstat;
for(keys %$msgstat){
    my $content = Report($msgstat,$_,$ARGV[0]);
    print "====>$_\n$content\n" if $content;
}

sub Report{
    my $msgstat = shift;
    my $group_name = shift;
    my $top = shift;
    $top>0?($top--):($top=10);
    my $content = "";
    my @sort_qq = 
    sort {$msgstat->{$group_name}{$b}{other_img}<=>$msgstat->{$group_name}{$a}{other_img} or $msgstat->{$group_name}{$b}{other_img}/$msgstat->{$group_name}{$b}{msg} <=> $msgstat->{$group_name}{$a}{other_img}/$msgstat->{$group_name}{$a}{msg}}
    grep {$msgstat->{$group_name}{$_}{msg}!=0}
    keys %{$msgstat->{$group_name}};
    
    my @top_qq = @sort_qq[0..$top];
    for(@top_qq){
        #next if $msgstat->{$group_name}{$_}{other_img} ==0;
        next if $msgstat->{$group_name}{$_}{msg} ==0;
        my $nick = $msgstat->{$group_name}{$_}{card}||$msgstat->{$group_name}{$_}{nick};
        $content .= sprintf("%4s  %4s  %4s  %s\n",
            $msgstat->{$group_name}{$_}{msg}+0,
            $msgstat->{$group_name}{$_}{other_img}+0,
            sprintf("%.1f",($msgstat->{$group_name}{$_}{other_img})*100/$msgstat->{$group_name}{$_}{msg}),
            $nick,  
        );
    } 
    $content = sprintf("%4s  %4s  %4s  %s\n","消息","图片","水度","昵称") . $content if $content;
    return $content;
}

