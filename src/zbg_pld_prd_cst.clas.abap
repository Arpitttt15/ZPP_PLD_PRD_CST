CLASS zbg_pld_prd_cst DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_operation.
    INTERFACES if_bgmc_op_single_tx_uncontr.
    INTERFACES if_serializable_object.

    " ✅ Updated constructor to only require Order ID and the Mail Indicator
    METHODS constructor
      IMPORTING
        iv_order TYPE aufnr
        iv_m_ind TYPE abap_boolean.

  PROTECTED SECTION.
    " ✅ Cleaned up attributes to match new parameters
    DATA: im_order TYPE aufnr,
          im_ind   TYPE abap_boolean.

    METHODS modify RAISING cx_bgmc_operation.

ENDCLASS.



CLASS ZBG_PLD_PRD_CST IMPLEMENTATION.


  METHOD constructor.
    im_order = iv_order.
    im_ind   = iv_m_ind.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.
    modify( ).
  ENDMETHOD.


  METHOD modify.

    DATA: wa_data      TYPE ztb_ppc,
          lv_msg       TYPE string,
          lv_saved_pdf TYPE string,
          lv_orderid   TYPE aufnr,
          lv_mat_code  TYPE matnr,
          lv_cust_code TYPE kunnr.
    " ✅ Normalize order ID format (Adds leading zeros if missing)
    lv_orderid = im_order.
    lv_orderid = |{ lv_orderid ALPHA = IN }|.

    SELECT SINGLE *
       FROM ztb_ppc
       WHERE orderid = @lv_orderid
       INTO @wa_data.

    IF sy-subrc <> 0.
      CLEAR wa_data.
      wa_data-client  = sy-mandt.
      wa_data-orderid = lv_orderid.
    ENDIF.

    " ── STEP 2: Fetch Material Code from Order Header ────────────────────
    SELECT SINGLE material
      FROM i_manufacturingorder WITH PRIVILEGED ACCESS
      WHERE manufacturingorder = @lv_orderid
      INTO @lv_mat_code.

    " ═══════════════════════════════════════════════
    " CASE 1 : ZPRINT (Generate and Save PDF)
    " ═══════════════════════════════════════════════
    IF im_ind = abap_false.

      DATA(lo_pfd) = NEW zcl_pld_prd_cst( ).
      DATA(pdf_64) = lo_pfd->get_pdf_64( io_orderid = lv_orderid ).

      IF pdf_64 IS NOT INITIAL.
        " Update required fields (wa_data already holds customer, freight, etc.)
        wa_data-base64 = pdf_64.
        wa_data-m_ind  = im_ind.

        MODIFY ztb_ppc FROM @wa_data.
      ENDIF.

    ENDIF.

    " ═══════════════════════════════════════════════
    " CASE 2 : ZSENDMAIL clicked → Read PDF and Send
    " ═══════════════════════════════════════════════
    IF im_ind = abap_true.

      SELECT SINGLE base64 FROM ztb_ppc WHERE orderid = @lv_orderid INTO @lv_saved_pdf.

      IF lv_saved_pdf IS INITIAL.
        lv_saved_pdf = NEW zcl_pld_prd_cst( )->get_pdf_64( io_orderid = lv_orderid ).
      ENDIF.

      IF lv_saved_pdf IS NOT INITIAL.
        " Pass the codes fetched at the start of the method
        zcl_pld_cst_mail=>send_mail(
          EXPORTING
            iv_orderid   = lv_orderid
            iv_material  = lv_mat_code
            iv_cust_code = CONV #( wa_data-customer )
            iv_pdf64     = lv_saved_pdf
          IMPORTING
            ev_message   = lv_msg
        ).
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
