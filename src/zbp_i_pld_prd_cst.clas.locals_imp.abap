CLASS lhc_zi_pld_prd_cst_doc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_pld_prd_cst_doc RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_pld_prd_cst_doc RESULT result.

    METHODS zprint FOR MODIFY
      IMPORTING keys FOR ACTION zi_pld_prd_cst_doc~zprint RESULT result.

    METHODS zsendmail FOR MODIFY
      IMPORTING keys FOR ACTION zi_pld_prd_cst_doc~zsendmail RESULT result.

ENDCLASS.

CLASS lhc_zi_pld_prd_cst_doc IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD zsendmail.

  DATA: lt_update TYPE TABLE FOR UPDATE zi_pld_prd_cst,
        ls_update TYPE STRUCTURE FOR UPDATE zi_pld_prd_cst.

  READ ENTITIES OF zi_pld_prd_cst IN LOCAL MODE
    ENTITY zi_pld_prd_cst_doc
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  LOOP AT lt_data INTO DATA(ls_data).

    CLEAR ls_update.

    ls_update-%tky  = ls_data-%tky.
    ls_update-m_ind = abap_true.

    APPEND ls_update TO lt_update.


  ENDLOOP.

  MODIFY ENTITIES OF zi_pld_prd_cst IN LOCAL MODE
    ENTITY zi_pld_prd_cst_doc
    UPDATE FIELDS ( m_ind )
    WITH lt_update
    REPORTED reported
    FAILED failed.

  APPEND VALUE #(
    %tky = keys[ 1 ]-%tky
    %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-success
              text     = 'Mail request submitted successfully'
           )
  ) TO reported-zi_pld_prd_cst_doc.

ENDMETHOD.

  METHOD zprint.

    DATA lo_pfd TYPE REF TO zcl_pld_prd_cst. "<-write your logic class

    CREATE OBJECT lo_pfd.

    READ ENTITIES OF zi_pld_prd_cst IN LOCAL MODE "<-write your interface name
           ENTITY zi_pld_prd_cst_doc  "<-write your interface name
          ALL FIELDS WITH CORRESPONDING #( keys )
          RESULT DATA(lt_result).

    LOOP AT lt_result INTO DATA(lw_result).

      DATA : update_lines TYPE TABLE FOR UPDATE  zi_pld_prd_cst,   "<-write your interface name
             update_line  TYPE STRUCTURE FOR UPDATE  zi_pld_prd_cst.   "<-write your interface name

      update_line-%tky                   = lw_result-%tky.
      update_line-base64                 = 'A'.

      IF update_line-base64 IS NOT INITIAL.

        APPEND update_line TO update_lines.

        MODIFY ENTITIES OF  zi_pld_prd_cst IN LOCAL MODE    "<-write your interface name
         ENTITY zi_pld_prd_cst_doc    "<-write your interface behaviour definition name
           UPDATE
           FIELDS ( base64 )
           WITH update_lines
         REPORTED reported
         FAILED failed
         MAPPED mapped.

        READ ENTITIES OF zi_pld_prd_cst IN LOCAL MODE  ENTITY zi_pld_prd_cst_doc  "<-write your interface name and behaviour definition name
            ALL FIELDS WITH CORRESPONDING #( lt_result ) RESULT DATA(lt_final).

        result =  VALUE #( FOR  lw_final IN  lt_final ( %tky = lw_final-%tky
         %param = lw_final  )  ).

        APPEND VALUE #( %tky = keys[ 1 ]-%tky
                        %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-success
                        text = 'PDF Generated!, Please Wait for 30 Sec' )
                         ) TO reported-zi_pld_prd_cst_doc.    "<-write your interface behaviour definition name

      ELSE.

      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lsc_zi_pld_prd_cst DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_pld_prd_cst IMPLEMENTATION.

  METHOD save_modified.

    DATA wa_data TYPE ztb_ppc.

    LOOP AT update-zi_pld_prd_cst_doc INTO DATA(ls_data).

      CLEAR wa_data.

      DATA(lv_orderid) = ls_data-orderid.
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

      " ✅ Update fields
      IF ls_data-%control-salesunitprice = if_abap_behv=>mk-on.
        wa_data-salesunitprice = ls_data-salesunitprice.
      ENDIF.

      IF ls_data-%control-freight = if_abap_behv=>mk-on.
        wa_data-freight = ls_data-freight.
      ENDIF.

      IF ls_data-%control-customer = if_abap_behv=>mk-on.
        wa_data-customer = ls_data-customer.
      ENDIF.

      IF ls_data-%control-base64 = if_abap_behv=>mk-on.
        wa_data-base64 = ls_data-base64.
      ENDIF.

      " 🔥 SAVE FIRST (VERY IMPORTANT)
      MODIFY ztb_ppc FROM @wa_data.

    ENDLOOP.

    LOOP AT update-zi_pld_prd_cst_doc INTO ls_data.

      DATA(new) = NEW zbg_pld_prd_cst(
                    iv_order = ls_data-orderid
                    iv_m_ind = ls_data-m_ind ).

      TRY.
          DATA(background_process) =
            cl_bgmc_process_factory=>get_default( )->create( ).

          background_process->set_operation_tx_uncontrolled( new ).
          background_process->save_for_execution( ).

        CATCH cx_bgmc INTO DATA(exception).
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
