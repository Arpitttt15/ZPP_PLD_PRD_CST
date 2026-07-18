CLASS zcl_pld_cst_mail DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS send_mail
      IMPORTING
        iv_orderid       TYPE i_manufacturingorder-manufacturingorder
        iv_material      TYPE matnr
        iv_cust_code     TYPE kunnr
        iv_pdf64         TYPE string OPTIONAL   " ✅ Optional base64 PDF
      EXPORTING
        ev_message       TYPE string.

ENDCLASS.



CLASS ZCL_PLD_CST_MAIL IMPLEMENTATION.


  METHOD send_mail.

    DATA: lv_xstr   TYPE xstring,
          lv_body   TYPE string,
          lv_pdf64  TYPE string,
          lt_emails TYPE TABLE OF string.

    " ── STEP 1 : Fetch Configured Email IDs ──────────────────────
    " Fetch all emails configured for this specific class
    SELECT email_id
      FROM zemail_config
      WHERE class_name = 'ZCL_PLD_CST_MAIL'
      INTO TABLE @DATA(lt_config_emails).

    " Optional: Check if we actually found any emails before proceeding
    IF sy-subrc <> 0 OR lt_config_emails IS INITIAL.
      ev_message = 'ERROR: No recipient emails configured for this class.'.
      RETURN.
    ENDIF.

    " Move the fetched emails into the expected string table
    LOOP AT lt_config_emails INTO DATA(ls_email).
      APPEND ls_email-email_id TO lt_emails.
    ENDLOOP.

    " ── STEP 2 : Resolve PDF base64 ──────────────────────────────
    IF iv_pdf64 IS NOT INITIAL.
      " ✅ Use passed PDF directly
      lv_pdf64 = iv_pdf64.
    ELSE.
      " Fallback: read from new table ztb_ppc
      SELECT SINGLE base64
        FROM ztb_ppc
        WHERE orderid = @iv_orderid
        INTO @lv_pdf64.

      " Last resort: regenerate using new class
      IF lv_pdf64 IS INITIAL.
        DATA(lo_conf) = NEW zcl_pld_prd_cst( ).

        lv_pdf64 = lo_conf->get_pdf_64(
          io_orderid = iv_orderid
        ).
      ENDIF.
    ENDIF.

    IF lv_pdf64 IS INITIAL.
      ev_message = |ERROR: PDF empty for Order { iv_orderid }|.
      RETURN.
    ENDIF.

    " ── STEP 3 : Decode base64 → xstring ─────────────────────────
    TRY.
        lv_xstr = cl_web_http_utility=>decode_x_base64( lv_pdf64 ).
      CATCH cx_sy_conversion_error INTO DATA(lx_conv).
        ev_message = |ERROR: Decode failed - { lx_conv->get_text( ) }|.
        RETURN.
    ENDTRY.

    IF lv_xstr IS INITIAL.
      ev_message = 'ERROR: XSTRING empty after decode'.
      RETURN.
    ENDIF.

    " ── STEP 4 : Build Body ───────────────────────────────────────
    lv_body =
      |DISCLAIMER<br><br>| &&
      |This e-mail is for the sole use of the intended recipient(s). It may contain<br>| &&
      |information that is confidential and/or legally privileged. If you believe<br>| &&
      |that it has been sent to you in error, please notify the sender by reply<br>| &&
      |e-mail and delete the message. Any disclosure, copying, distribution or use<br>| &&
      |of this information by someone other than the intended recipient is<br>| &&
      |prohibited.|.

    " ── STEP 5 : Send ────────────────────────────────────────────
    TRY.
        DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).

        DATA(lv_filename) = |COST { iv_orderid ALPHA = OUT } { iv_material ALPHA = OUT } { iv_cust_code ALPHA = OUT }.pdf|.
        CONDENSE lv_filename.
        " ✅ Loop and add all hardcoded recipients
        LOOP AT lt_emails INTO DATA(lv_email).
          lo_mail->add_recipient(
            iv_address = CONV #( lv_email )
          ).
        ENDLOOP.

        lo_mail->set_sender(
          iv_address = 'noreply@mpmindia.in.mail.s4hana.ondemand.com'
        ).

        lo_mail->set_subject( 'Planned Production Cost Sheet' ).

        lo_mail->set_main(
          cl_bcs_mail_textpart=>create_instance(
            iv_content      = lv_body
            iv_content_type = 'text/html'
          )
        ).

        " ✅ Attach PDF (Updated filename to match context)
        DATA(lo_att) = cl_bcs_mail_binarypart=>create_instance(
          iv_content      = lv_xstr
          iv_content_type = 'application/pdf'
          iv_filename     = lv_filename
        ).

        lo_mail->add_attachment( lo_att ).

        lo_mail->send(
          IMPORTING et_status = DATA(lt_status)
        ).

        ev_message = |SUCCESS: Mail sent to recipients for Order { iv_orderid }|.

      CATCH cx_bcs_mail INTO DATA(lx_mail).
        ev_message = |MAIL ERROR: { lx_mail->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
