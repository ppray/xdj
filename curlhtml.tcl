#!/usr/bin/env tclsh
#package require Expect

source /root/xdj/func_base.tcl
source /root/xdj/account

#// whether use argv, special id
set sid [lindex $argv 0]


    #// check available proxy
    #catch {exec /root/xdj/proxy/pxconfig.tcl} err
    #puts "Following proxy are checked\n$err"
    #puts "\n======== Start Tracking ========\n"

	#//query data
    if {$sid==""} {
        set url_table [exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;select ID,price1,date1,url,merchant,owner,Product from xindijia where del=0 order by ID;"]
        #set url_table [exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;select ID,price1,date1,url,merchant,owner,product from xindijia where ID='71';"]
    } else {
        set url_table [exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;select ID,price1,date1,url,merchant,owner,Product from xindijia where ID='$sid';"]
    }
    if {$url_table==""} {
        puts "ERROR: Didn't find any URL of this merchant, please check"
    	return
    }
    
    set f [open /root/xdj/curl.log a+]
    set url_list [split $url_table \n]
	set timestamp1 [clock seconds]
    set proxylist [exec cat /root/xdj/proxy/proxylist.txt]
	if {$proxylist==""} {
	    puts "ERROR: No available Proxy"
	    mailx "ERROR: No available Proxy" "ERROR: No available Proxy"
	    return
	}
	# tp: total proxy number
	set tp [llength $proxylist]
	set p_index 0
	#// Query price for each product
    foreach element $url_list {
        set id [lindex $element 0]
    	#skip the first title line
    	if {$id=="ID"} {
    		continue
        }
    	#if {$id != 4} {continue}
    	set price1 [lindex $element 1]
    	set date1 "[lindex $element 2] [lindex $element 3]"
		#//date1 is two element when pickup, like 2014-12-14 20:17:21, so url start from index 4
    	set url [lindex $element 4]
    	set merchant [lindex $element 5]
    	set owner [lindex $element 6]
		set product [lrange $element 7 end]
    	#// current date time
    	set cdate [exec date "+%y-%m-%d %T"]
    	#download web page if url is available
    	if [regexp "http" $url] {
    	    #puts "id is $id, url is $url"
    		#puts "curl -A \"Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)\" -o html/$id $url"

            puts "Check No.$id ......"
			if {$proxylist !=""} {
                #puts "Check No.$id with proxy $proxy ......"
                set retry 1
                while {$retry<=$tp} {
				    set proxy [lindex $proxylist $p_index]
                    incr retry
                    if {$p_index>=[expr $tp-1]} {
                        set p_index 0
                    } else {
                        incr p_index
                    }
			        catch {exec curl -A "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)" -x $proxy -o /root/xdj/html/$id $url} err
                    if [regexp -line {100\s+\d+[k]*} $err] {
                        break
                    }
                }
                if {$retry>=$tp} {
                    puts "ERROR: ALL [expr $retry - 1] proxy didn't work" 
                } else {
                    puts "PASS: Get the No.$id page after [expr $retry - 1] time(s) trying"
                }
			    #catch {exec curl -A "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)" -x $proxy -o /root/xdj/html/$id $url} err
                #if ![regexp -line {100\s+\d+[k]*} $err] {
				#    puts $err
                #    puts "ERROR: Proxy $proxy dosen't work, try next proxy IP !!"
                #    incr p_index
				#    set proxy [lindex $proxylist $p_index]
			    #    #catch {exec curl -A "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)" -o /root/xdj/html/$id $url} err
			    #    catch {exec curl -A "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)" -x $proxy -o /root/xdj/html/$id $url} err
				#	if ![regexp -line {100\s+\d+[k]*} $err] {
				#        puts $err
                #        puts "ERROR: Proxy $proxy still dosen't work, tell administrator!!"
                #        #puts "ERROR: Local IP still can't get page!!"
				#        mailx "ERROR: Proxy $proxy still can't get page for $id" $err
				#	}
                #}
		    } else {
                puts "ERROR: No proxy!!"
				mailx "ERROR: No proxy!!"
			    catch {exec curl -A "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)" -o /root/xdj/html/$id $url} err
		    }
            if {$p_index>=[expr $tp-1]} {
                set p_index 0
				#puts "sleep 2 seconds"
				#after 2000
            } else {
                incr p_index
            }

			#// without proxy
    		#if !{[catch {exec curl -A "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)" -o /root/xdj/html/$id $url} err]} {
    		#    puts $f $err
			#    continue
    		#}

    		#// Get price
    		set page [exec cat /root/xdj/html/$id]
    		set price_list [get_price $merchant $page]
    		set cprice [lindex $price_list 1]
    		#// Bug, set status 9
            if {$cprice<=0 || $cprice==""} {
    		    catch {exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;update xindijia set status='9' where ID=$id;"}
                #puts "No.$id current price is $cprice, best price is $price1"
		        puts "\n"
				puts $info
				puts "ERROR: No.$id failed to get price with proxy $proxy !"
		        puts "\n"
    			continue
    		}
    		#// Best price, set status 1
    		if {$cprice<=$price1} {
			    if {$cprice==$price1} {
    		        catch {exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;update xindijia set status='1',cprice='$cprice',cdate='$cdate',date1='$cdate' where ID=$id;"}
				    set subject "$product 价格$cprice , 好价再袭！"
		            set date1_seconds [clock scan $date1]
		            set cdate_seconds [clock scan $cdate]
                    if {[expr $cdate_seconds - $date1_seconds]>86400} {
				        set content "$product 价格$cprice , 上一次历史低价为$price1 时间是$date1. \n直达链接：www.aapay.net/track/#tracktable"
                        set email [lindex [exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;select email from test_user where username='$owner';"] 1]
				        mailx $subject $content $email
                    }
			    } else {
    		        catch {exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;update xindijia set status='1',cdate='$cdate',cprice='$cprice',price1='$cprice',date1='$cdate',price2='$cprice',date2='$cdate' where ID=$id;"}
				    set subject "$product 价格$cprice , 新低价，速抢！！！"
				    set content "$product 价格$cprice , 上一次历史低价为$price1 时间是$date1. \n直达链接：www.aapay.net/track/#tracktable"
                    set email [lindex [exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;select email from test_user where username='$owner';"] 1]
					#set email ppray@163.com
				    mailx $subject $content $email
				}
                puts $subject
                #puts "No.$id current price $cprice is best, last best price was $price1 !!!"
    		    continue
    		}
    		#// Good price, set status 2
            if {$cprice>$price1 && $cprice<=[expr $price1*1.1]} {
    		    catch {exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;update xindijia set status='2',cdate='$cdate',cprice='$cprice' where ID=$id;"}
                puts "No.$id current price $cprice is good price, best price is $price1"
				set subject "$product 价格$cprice , 近期好价！"
				#set clean_url [regsub {http://} $url {}]
				#set content "$product 价格$cprice , 上一次历史低价为$price1 时间是$date1. \n直达链接：$clean_url"
				#mailx $subject $content
    		    continue
    		}
    		#// Just soso price, set status 3
            if {$cprice>[expr $price1*1.1] && $cprice<=[expr $price1*1.2]} {
    		    catch {exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;update xindijia set status='3',cdate='$cdate',cprice='$cprice' where ID=$id;"}
                puts "No.$id current price $cprice is just so so, best price is $price1"
    		    continue
    		}
    		catch {exec $mysqldir/mysql -u$usr -p$pwd -hlocalhost -e "use fantuan;update xindijia set status='0',cdate='$cdate',cprice='$cprice' where ID=$id;"}
            #puts "No.$id current price is $cprice, best price is $price1"
    		#puts $price_list
    		#puts $err
    	} else {
    	    puts "Jump id $id"
    	    puts $f "Jump id $id"
    		continue
    	}
    }
    close $f
	set timestamp2 [clock seconds]
	set duration [expr $timestamp2 - $timestamp1]
	set sleeping [expr 21600 - $duration]
	puts [exec date]
	puts "Totally spent [expr $duration/60] minutes analyzing, won't Sleep [expr $sleeping/3600] hours"
	#after [expr $sleeping*1000]

