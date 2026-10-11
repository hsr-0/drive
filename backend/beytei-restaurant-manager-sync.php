<?php
/**
 * Plugin Name: Beytei Restaurant Manager Sync
 * Description: Authenticated restaurant menu management and verified manual courier dispatch.
 * Version: 1.0.0
 */
defined('ABSPATH') || exit;

function bms_restaurant_id() {
    $user_id = get_current_user_id();
    if (!$user_id || !(current_user_can('restaurant_owner') || current_user_can('manage_woocommerce'))) {
        return new WP_Error('forbidden', 'يجب تسجيل الدخول بصلاحية مدير المطعم', ['status' => 403]);
    }
    $id = (int) get_user_meta($user_id, 'restaurant_category_id', true);
    $term = $id ? get_term($id, 'product_cat') : null;
    if (!$term || is_wp_error($term) || (int) $term->parent !== 0) {
        return new WP_Error('no_restaurant', 'هذا الحساب غير مرتبط بمطعم صالح', ['status' => 403]);
    }
    return $id;
}
function bms_child_category($category_id, $restaurant_id) {
    $term = $category_id ? get_term((int) $category_id, 'product_cat') : null;
    return $term && !is_wp_error($term) && (int) $term->parent === (int) $restaurant_id;
}
function bms_owned_product($product_id, $restaurant_id) {
    $product = wc_get_product($product_id);
    if (!$product) return new WP_Error('not_found', 'الوجبة غير موجودة', ['status' => 404]);
    $cats = get_the_terms($product_id, 'product_cat');
    if ($cats && !is_wp_error($cats)) foreach ($cats as $cat) {
        if ((int) $cat->term_id === $restaurant_id || (int) $cat->parent === $restaurant_id) return $product;
    }
    return new WP_Error('unauthorized', 'هذه الوجبة لا تتبع مطعمك', ['status' => 403]);
}
function bms_image($b64, $name) {
    if (!is_string($b64) || strlen($b64) > 6 * 1024 * 1024) return new WP_Error('image_large', 'الصورة كبيرة جداً', ['status'=>400]);
    $b64 = preg_replace('#^data:image/[^;]+;base64,#', '', $b64);
    $bytes = base64_decode($b64, true);
    if (!$bytes || strlen($bytes) > 4 * 1024 * 1024) return new WP_Error('image_invalid', 'الصورة غير صالحة', ['status'=>400]);
    $info = @getimagesizefromstring($bytes);
    $ext = ['image/jpeg'=>'jpg', 'image/png'=>'png', 'image/webp'=>'webp'][$info['mime'] ?? ''] ?? '';
    if (!$ext) return new WP_Error('image_type', 'الصورة يجب أن تكون JPG أو PNG أو WebP', ['status'=>400]);
    $file = wp_upload_bits(sanitize_file_name($name) . '-' . wp_generate_uuid4() . '.' . $ext, null, $bytes);
    if (!empty($file['error'])) return new WP_Error('image_upload', 'تعذر حفظ الصورة', ['status'=>500]);
    $id = wp_insert_attachment(['post_mime_type'=>$info['mime'], 'post_title'=>sanitize_text_field($name), 'post_status'=>'inherit'], $file['file']);
    if (is_wp_error($id)) return $id;
    require_once ABSPATH . 'wp-admin/includes/image.php';
    wp_update_attachment_metadata($id, wp_generate_attachment_metadata($id, $file['file']));
    return (int)$id;
}
function bms_validate_prices($data, $required = true) {
    if (!$required && !array_key_exists('regular_price', $data) && !array_key_exists('sale_price', $data)) return true;
    if (isset($data['regular_price']) && (!is_numeric($data['regular_price']) || (float) $data['regular_price'] <= 0)) return new WP_Error('bad_price', 'السعر الأصلي يجب أن يكون موجباً', ['status'=>400]);
    if ($required && !isset($data['regular_price'])) return new WP_Error('bad_price', 'يرجى تحديد السعر الأصلي', ['status'=>400]);
    if (isset($data['sale_price']) && $data['sale_price'] !== '' && $data['sale_price'] !== null &&
        (!is_numeric($data['sale_price']) || (float) $data['sale_price'] <= 0)) return new WP_Error('bad_sale', 'سعر العرض غير صالح', ['status'=>400]);
    if (isset($data['regular_price'], $data['sale_price']) && $data['sale_price'] !== '' && $data['sale_price'] !== null &&
        (float) $data['sale_price'] >= (float) $data['regular_price']) return new WP_Error('bad_sale', 'سعر العرض يجب أن يقل عن السعر الأصلي', ['status'=>400]);
    return true;
}
function bms_context() {
    $id = bms_restaurant_id();
    if (is_wp_error($id)) return $id;
    $term = get_term($id, 'product_cat');
    $lat = get_term_meta($id, 'restaurant_latitude', true) ?: get_term_meta($id, '_restaurant_latitude', true);
    $lng = get_term_meta($id, 'restaurant_longitude', true) ?: get_term_meta($id, '_restaurant_longitude', true);
    $area_ids = (array) get_term_meta($id, 'delivery_areas', true);
    $areas = [];
    foreach ($area_ids as $area_id) {
        $area = get_term((int)$area_id, 'area');
        if ($area && !is_wp_error($area)) $areas[] = ['id'=>(int)$area->term_id, 'name'=>$area->name];
    }
    return ['id'=>$id, 'name'=>$term->name, 'latitude'=>(float)$lat, 'longitude'=>(float)$lng, 'areas'=>$areas];
}
function bms_my_products() {
    $rid = bms_restaurant_id();
    if (is_wp_error($rid)) return $rid;
    $posts = get_posts([
        'post_type'=>'product', 'post_status'=>['publish','draft'],
        'posts_per_page'=>-1, 'fields'=>'ids',
        'tax_query'=>[['taxonomy'=>'product_cat','field'=>'term_id','terms'=>[$rid],'include_children'=>true]]
    ]);
    $list = [];
    foreach ($posts as $id) {
        $product = wc_get_product($id);
        if (!$product) continue;
        $cat_id = $rid; $cat_name = get_term($rid)->name;
        foreach ((array) get_the_terms($id, 'product_cat') as $term) {
            if (is_object($term) && isset($term->parent) && (int)$term->parent === $rid) {
                $cat_id = (int)$term->term_id; $cat_name = $term->name; break;
            }
        }
        $url = $product->get_image_id() ? wp_get_attachment_image_url($product->get_image_id(), 'medium') : '';
        $list[] = [
            'id'=>$product->get_id(), 'name'=>$product->get_name(),
            'regular_price'=>$product->get_regular_price(), 'sale_price'=>$product->get_sale_price(),
            'short_description'=>$product->get_short_description(),
            'status'=>$product->get_status(), 'categories'=>[['id'=>$cat_id,'name'=>$cat_name]],
            'images'=>$url ? [['src'=>$url]] : []
        ];
    }
    return rest_ensure_response($list);
}
function bms_save_product(WP_REST_Request $request) {
    $rid = bms_restaurant_id();
    if (is_wp_error($rid)) return $rid;
    $data = (array) $request->get_json_params();
    $creating = !$request->get_param('product_id');
    $category_id = (int)($data['category_id'] ?? 0);
    if ($creating && !$category_id) return new WP_Error('category_required','اختر القسم أولاً',['status'=>400]);
    if ($category_id && !bms_child_category($category_id,$rid)) return new WP_Error('bad_category','هذا القسم لا يتبع المطعم',['status'=>403]);
    $prices = bms_validate_prices($data, $creating);
    if (is_wp_error($prices)) return $prices;
    if ($creating && !trim((string)($data['name']??''))) return new WP_Error('name_required','اسم الوجبة مطلوب',['status'=>400]);
    $product = $creating ? new WC_Product_Simple() : bms_owned_product((int)$data['product_id'],$rid);
    if (is_wp_error($product)) return $product;
    if (array_key_exists('name',$data)) $product->set_name(sanitize_text_field($data['name']));
    if (array_key_exists('regular_price',$data)) $product->set_regular_price(wc_format_decimal($data['regular_price']));
    $regular_price = (float)$product->get_regular_price();
    if (array_key_exists('sale_price',$data)) {
        $sale = ($data['sale_price']===null || $data['sale_price']==='') ? '' : wc_format_decimal($data['sale_price']);
        if ($sale !== '' && (float)$sale >= $regular_price) return new WP_Error('bad_sale','سعر العرض يجب أن يقل عن السعر الأصلي',['status'=>400]);
        $product->set_sale_price($sale);
    }
    if (array_key_exists('description',$data)) $product->set_short_description(sanitize_textarea_field($data['description']));
    if ($category_id) $product->set_category_ids([$category_id]);
    if (!empty($data['image_base64'])) {
        $image_id = bms_image($data['image_base64'], $product->get_name());
        if (is_wp_error($image_id)) return $image_id;
        $product->set_image_id($image_id);
    }
    if ($creating) $product->set_status('publish');
    $id = $product->save();
    if (!$id) return new WP_Error('save_failed','فشل حفظ الوجبة',['status'=>500]);
    wc_delete_product_transients($id);
    return new WP_REST_Response(['success'=>true,'product_id'=>$id],$creating ? 201 : 200);
}
function bms_toggle_product(WP_REST_Request $request) {
    $rid = bms_restaurant_id(); if (is_wp_error($rid)) return $rid;
    $product = bms_owned_product((int)$request->get_param('product_id'),$rid);
    if (is_wp_error($product)) return $product;
    $hide = filter_var($request->get_param('is_hidden'), FILTER_VALIDATE_BOOLEAN);
    $product->set_status($hide ? 'draft' : 'publish');
    $product->save();
    wc_delete_product_transients($product->get_id());
    return ['success'=>true,'current_status'=>$product->get_status()];
}
function bms_delete_product(WP_REST_Request $request) {
    $rid=bms_restaurant_id(); if(is_wp_error($rid)) return $rid;
    $product=bms_owned_product((int)$request->get_param('product_id'),$rid);
    if(is_wp_error($product)) return $product;
    $id=$product->get_id();
    if(!wp_trash_post($id)) return new WP_Error('trash_error','فشل نقل الوجبة إلى سلة المحذوفات',['status'=>500]);
    wc_delete_product_transients($id);
    return ['success'=>true,'product_id'=>$id];
}
function bms_delete_category(WP_REST_Request $request) {
    $rid=bms_restaurant_id(); if(is_wp_error($rid)) return $rid;
    $cid=(int)$request->get_param('term_id');
    if(!bms_child_category($cid,$rid)) return new WP_Error('bad_category','هذا القسم لا يتبع مطعمك',['status'=>403]);
    $children=get_terms(['taxonomy'=>'product_cat','parent'=>$cid,'hide_empty'=>false,'fields'=>'ids']);
    if(is_wp_error($children)) return $children;
    if($children) return new WP_Error('category_not_empty','القسم يحتوي على أقسام أخرى',['status'=>409]);
    $assigned=get_objects_in_term($cid,'product_cat');
    if(is_wp_error($assigned)) return $assigned;
    foreach ($assigned as $object_id) if(get_post_type($object_id)==='product' && get_post_status($object_id)!=='trash')
        return new WP_Error('category_not_empty','انقل أو احذف الوجبات من القسم أولاً',['status'=>409]);
    $deleted=wp_delete_term($cid,'product_cat');
    if(!$deleted || is_wp_error($deleted)) return new WP_Error('delete_failed','فشل حذف القسم',['status'=>500]);
    return ['success'=>true];
}
// Only accept coordinates from the actual customer's shared location.
// No fictitious driver/restaurant locations, no client-supplied fees or taxi secrets.
function bms_manager_request_driver(WP_REST_Request $request) {
    $context=bms_context(); if(is_wp_error($context)) return $context;
    if(!function_exists('auto_dispatch_taxi_request_unified') || !function_exists('handle_get_delivery_config'))
        return new WP_Error('dispatch_unavailable','خدمة المندوب غير مجهزة على السيرفر',['status'=>503]);
    $body=(array)$request->get_json_params();
    $phone=preg_replace('/[^0-9+]/','',(string)($body['phone']??''));
    $address=sanitize_text_field($body['address']??'');
    $zone=(int)($body['zone_id']??0);
    $lat=filter_var($body['destination_lat']??null,FILTER_VALIDATE_FLOAT);
    $lng=filter_var($body['destination_lng']??null,FILTER_VALIDATE_FLOAT);
    if(strlen($phone)<10 || !trim($address)) return new WP_Error('customer_required','رقم الزبون والعنوان مطلوبان',['status'=>400]);
    if($lat===false || $lng===false || abs($lat)>90 || abs($lng)>180 || $lat==0 || $lng==0)
        return new WP_Error('invalid_location','يجب إدخال موقع الزبون الحقيقي',['status'=>400]);
    if(!$context['latitude'] || !$context['longitude']) return new WP_Error('restaurant_location','موقع المطعم غير محفوظ',['status'=>400]);
    $allowed=array_column($context['areas'],'id');
    if(!$zone || !in_array($zone,$allowed,true)) return new WP_Error('invalid_zone','اختر منطقة توصيل معتمدة للمطعم',['status'=>400]);
    $config_response=handle_get_delivery_config(new WP_REST_Request('GET','/'));
    $config=$config_response instanceof WP_REST_Response ? $config_response->get_data() : null;
    if(!is_array($config)) return new WP_Error('fee_config','تعذر قراءة أجرة التوصيل',['status'=>503]);
    $km=6371 * 2 * asin(min(1,sqrt(pow(sin(deg2rad($lat-$context['latitude'])/2),2) +
        cos(deg2rad($context['latitude']))*cos(deg2rad($lat))*pow(sin(deg2rad($lng-$context['longitude'])/2),2))));
    if($km > (float)($config['max_distance_km']??0)) return new WP_Error('too_far','الزبون خارج نطاق التوصيل',['status'=>400]);
    $fee=ceil(((float)($config['base_fee']??0)+$km*(float)($config['fee_per_km']??0))/250)*250;
    if($fee<=0) return new WP_Error('fee_invalid','إعدادات التسعير غير مكتملة',['status'=>503]);
    // Block repeat taps for this restaurant/customer/address for 60 seconds.
    $lock='bms_dispatch_'.md5($context['id'].'|'.$phone.'|'.$address.'|'.$lat.'|'.$lng);
    if(get_transient($lock)) return new WP_Error('duplicate_request','تم إرسال نفس الطلب قبل قليل',['status'=>409]);
    set_transient($lock,1,60);
    // Disable legacy dispatch hooks only while constructing the complete order.
    $hooks=[
        ['woocommerce_new_order','auto_dispatch_taxi_request_unified',20,1],
        ['woocommerce_order_status_processing','auto_dispatch_taxi_request_unified',20,1],
        ['woocommerce_order_status_changed','force_dispatch_on_status_change',10,4],
    ];
    $removed=[];
    foreach ($hooks as $h) {
        $priority=has_action($h[0],$h[1]);
        if($priority!==false) { remove_action($h[0],$h[1],$priority); $removed[]=[$h[0],$h[1],$priority,$h[3]]; }
    }
    try {
        $order=wc_create_order();
        if(is_wp_error($order)) throw new Exception($order->get_error_message());
        $item=new WC_Order_Item_Product();
        $item->set_name('طلب مندوب من '.$context['name']);
        $item->set_quantity(1); $item->set_total(0); $item->set_subtotal(0);
        $order->add_item($item);
        $shipping=new WC_Order_Item_Shipping();
        $shipping->set_method_title('خدمة توصيل فقط'); $shipping->set_total($fee);
        $order->add_item($shipping);
        $order->set_billing_first_name('زبون '.$context['name']);
        $order->set_billing_phone($phone);
        $order->set_shipping_address_1($address);
        $order->update_meta_data('_restaurant_id',$context['id']);
        $order->update_meta_data('zone_id',$zone);
        $order->update_meta_data('_shipping_lat',(string)$lat);
        $order->update_meta_data('_shipping_lng',(string)$lng);
        $order->update_meta_data('_is_manual_driver_request','yes');
        $order->update_meta_data('calculated_delivery_fee',$fee);
        $order->update_meta_data('calculated_final_total',$fee);
        $order->set_total($fee);
        $order->set_status('processing'); $order->save();
        $order_id=$order->get_id();
    } catch(Throwable $e) {
        delete_transient($lock);
        return new WP_Error('create_failed','لم يمكن إنشاء الطلب',['status'=>500]);
    } finally {
        foreach ($removed as $h) add_action($h[0],$h[1],$h[2],$h[3]);
    }
    auto_dispatch_taxi_request_unified($order_id);
    if(get_post_meta($order_id,'_taxi_auto_dispatch_done',true)!=='yes') {
        $order->add_order_note('تعذر تأكيد وصول طلب المندوب. يرجى متابعة الطلب في لوحة الإدارة.');
        return new WP_REST_Response(['success'=>false,'order_id'=>$order_id,'message'=>'تم حفظ الطلب لكن لم يؤكد سيرفر التكسي استلامه'],502);
    }
    return ['success'=>true,'order_id'=>$order_id,'delivery_fee'=>$fee,'message'=>'تم إرسال الطلب إلى نظام المندوبين'];
}
add_action('rest_api_init',function(){
    $ns='restaurant-app/v1';
    $guard=['permission_callback'=>function(){return is_user_logged_in() && (current_user_can('restaurant_owner') || current_user_can('manage_woocommerce'));}];
    // The final true overrides only these conflicting legacy routes.
    foreach([
        '/manager-context'=>['GET','bms_context'],
        '/my-products'=>['GET','bms_my_products'],
        '/create-product'=>['POST','bms_save_product'],
        '/update-product'=>['POST','bms_save_product'],
        '/toggle-product-visibility'=>['POST','bms_toggle_product'],
        '/delete-product'=>['POST','bms_delete_product'],
        '/delete-subcategory'=>['POST','bms_delete_category'],
        '/manager-request-driver'=>['POST','bms_manager_request_driver'],
    ] as $route=>$spec) {
        register_rest_route($ns,$route,[
            'methods'=>$spec[0], 'callback'=>$spec[1],
            'permission_callback'=>$guard['permission_callback']
        ],true);
    }
},999);
