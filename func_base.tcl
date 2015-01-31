## Get price from page
proc get_price {merchant page} {
    set price_list {}
    switch -nocase $merchant {
	    6pm {set op_pattern {oldPrice\">MSRP\s+\$([\d\.]+)}
		     set cp_pattern {pattern2 {price\">\s*\$([\d\.]+)}}
		}
	    amazon { set op_pattern {List Price:.*?\$([\d\.]+)</td>}
		         set cp_pattern {
		             pattern2 {>Price:.*?\$([\d\.]+)</span>}
				     pattern3 {<span id="buyingPriceValue".*?\$([\d\.]+).*</span>}
				     pattern4 {<span id="priceblock_saleprice".*?\$([\d\.]+).*</span>}
				     pattern5 {id="priceblock_dealprice".*?\$([\d\.]+).*</span>}
				     pattern6 {id="priceblock_ourprice".*?[\$￥]+\s*([\d\.\,]+).*</span>}
			     }
	    }
		jd  { 
		    set op_pattern "aapay.net"
		    set cp_pattern { pattern2 {<span.*?class="p-price">\&yen;([\d\.]+)\s*</span>} }
		}
	    default {set op_pattern "aapay.net"
		         set cp_pattern {pattern2 {aapay.net}}
		}
	}
	## op_pattern is used to match original price
	if [regexp $op_pattern $page - oldprice] {
	    lappend price_list $oldprice
	} else {
	    lappend price_list 0
	}
	## cp_pattern is uesd to match current price
    dict for {key value} $cp_pattern {
        if [regexp $value $page - price] {
		    regsub -all , $price "" price
            lappend price_list $price
            return $price_list
        }
    }
    lappend price_list 0
	return $price_list
}

## Send mail by mailx
proc mailx {subject content {email aapay2012@sina.com}} {
    catch {exec echo $content | mailx -s $subject $email} err   
	#puts $subject 
	#puts $content
	#puts $err
}
