class AccountsController < ApplicationController
  before_action :authenticate_request
  before_action :set_account, only: [:show]

  # GET /accounts
  def index
    accounts = policy_scope(Account).active

    render_success(
      message: I18n.t("accounts_listed", default: "Accounts retrieved successfully"),
      data: AccountRepresenter.render_collection(accounts)
    )
  end

  # GET /accounts/:id
  def show
    authorize @account

    render_success(
      message: I18n.t("account_retrieved", default: "Account retrieved successfully"),
      data: AccountRepresenter.render(@account, detailed: true)
    )
  end

  private

  def set_account
    @account = Account.find_by(id: account_params[:account_id])
    unless @account
      render_failure(message: I18n.t("account_not_found", default: "Account not found"), status: :not_found) and return
    end
  end

  def account_params
    { account_id: params[:id]}
end

end
